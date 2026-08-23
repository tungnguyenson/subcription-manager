import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subdock/extract/extraction_error.dart';
import 'package:subdock/extract/extraction_schema.dart';
import 'package:subdock/extract/openai_client.dart';

void main() {
  /// Wraps a canned reply. Nothing here touches the network.
  OpenAiClient clientReturning(
    String body, {
    int status = 200,
    Map<String, String> headers = const {},
    String? key = 'sk-test',
    void Function(http.Request request)? onRequest,
  }) {
    return OpenAiClient(
      httpClient: MockClient((request) async {
        onRequest?.call(request);
        // Bytes, not a String: http.Response(String, ...) encodes with the
        // response's charset, which would quietly sidestep the decoding path
        // this suite exists to cover.
        return http.Response.bytes(utf8.encode(body), status, headers: headers);
      }),
      apiKeyProvider: () => key,
    );
  }

  String responseWith(Map<String, dynamic> fields) => jsonEncode({
    'status': 'completed',
    'output': [
      {
        'content': [
          {'type': 'output_text', 'text': jsonEncode(fields)},
        ],
      },
    ],
  });

  const completeFields = {
    'source_type': 'billing_email',
    'service_name': 'Netflix',
    'service_name_raw': 'Netflix Premium',
    'amount_minor': 231000,
    'amount_raw': '231.000đ',
    'currency_code': 'VND',
    'currency_symbol_raw': 'đ',
    'billing_cycle': 'monthly',
    'billing_cycle_raw': 'hàng tháng',
    'due_date_iso': '2026-09-01',
    'due_date_raw': '01/09/2026',
    'date_format_detected': 'DMY',
    'confidence': 'high',
  };

  Future<ExtractionError> errorFrom(OpenAiClient client) async {
    try {
      await client.extract(text: 'x', todayIso: '2026-08-15', locale: 'vi-VN');
      fail('expected a failure');
    } on ExtractionException catch (e) {
      return e.error;
    }
  }

  test('a well-formed response parses into fields', () async {
    final client = clientReturning(responseWith(completeFields));
    final fields = await client.extract(
      text: 'Netflix Premium 231.000đ',
      todayIso: '2026-08-15',
      locale: 'vi-VN',
    );

    expect(fields.serviceName, 'Netflix');
    expect(fields.amountMinor, 231000);
    expect(fields.currencyCode, 'VND');
    expect(fields.billingCycle, BillingCycle.monthly);
    expect(fields.dueDateIso, '2026-09-01');
    expect(fields.confidence, Confidence.high);
  });

  // Strict mode forces every property into `required`, so the model can only
  // decline by sending null. A parse that rejected nulls would turn "I could
  // not find a date" into a crash, and the schema's whole purpose with it.
  test(
    'every field being absent is a valid response, not a parse error',
    () async {
      final client = clientReturning(
        responseWith(const {
          'source_type': 'unknown',
          'service_name': null,
          'service_name_raw': null,
          'amount_minor': null,
          'amount_raw': null,
          'currency_code': null,
          'currency_symbol_raw': null,
          'billing_cycle': null,
          'billing_cycle_raw': null,
          'due_date_iso': null,
          'due_date_raw': null,
          'date_format_detected': 'absent',
          'confidence': 'low',
        }),
      );

      final fields = await client.extract(
        text: 'nothing useful',
        todayIso: '2026-08-15',
        locale: 'vi-VN',
      );
      expect(fields.dueDateIso, isNull);
      expect(fields.amountMinor, isNull);
    },
  );

  test('no API key fails before any network call', () async {
    var called = false;
    final client = OpenAiClient(
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      apiKeyProvider: () => null,
    );

    expect(await errorFrom(client), isA<NoApiKey>());
    expect(called, isFalse, reason: 'must not hit the network without a key');
  });

  test(
    'an invalid key is reported as such, not as a retryable failure',
    () async {
      final error = await errorFrom(
        clientReturning('{"error":{"code":"invalid_api_key"}}', status: 401),
      );
      expect(error, isA<InvalidKey>());
      expect(error.retryable, isFalse);
    },
  );

  // 429 covers five conditions and three are permanent. Treating them all as
  // "back off and retry" leaves a user with no credit watching a spinner.
  test('429 for exhausted credit is not retryable', () async {
    final error = await errorFrom(
      clientReturning(
        '{"error":{"code":"credit_balance_exhausted"}}',
        status: 429,
      ),
    );
    expect(error, isA<CreditExhausted>());
    expect(error.retryable, isFalse);
  });

  test('429 for a spend limit is not retryable', () async {
    final error = await errorFrom(
      clientReturning(
        '{"error":{"code":"project_spend_limit_exceeded"}}',
        status: 429,
      ),
    );
    expect(error, isA<SpendLimitReached>());
    expect(error.retryable, isFalse);
  });

  test(
    '429 for genuine rate limiting is retryable and honours Retry-After',
    () async {
      final error = await errorFrom(
        clientReturning(
          '{"error":{"code":"rate_limit_exceeded"}}',
          status: 429,
          headers: {'retry-after': '12'},
        ),
      );
      expect(error, isA<RateLimited>());
      expect((error as RateLimited).retryAfterSeconds, 12);
      expect(error.retryable, isTrue);
    },
  );

  test('403 is reported as an unsupported region', () async {
    expect(
      await errorFrom(clientReturning('{"error":{}}', status: 403)),
      isA<RegionUnsupported>(),
    );
  });

  test('server errors are retryable', () async {
    final error = await errorFrom(clientReturning('oops', status: 503));
    expect(error, isA<ServerError>());
    expect(error.retryable, isTrue);
  });

  // A truncated strict-JSON body will not parse. Reporting that as a parse bug
  // would send the user chasing the wrong problem.
  test(
    'an incomplete response is reported as truncated rather than malformed',
    () async {
      final error = await errorFrom(
        clientReturning('{"status":"incomplete","output":[]}'),
      );
      expect(error, isA<Truncated>());
    },
  );

  test(
    'a refusal is surfaced as a refusal, since the schema is not honoured',
    () async {
      final error = await errorFrom(
        clientReturning(
          '{"status":"completed","output":[{"content":[{"refusal":"no"}]}]}',
        ),
      );
      expect(error, isA<Refused>());
      expect((error as Refused).reason, 'no');
    },
  );

  test('non-JSON output is reported as malformed', () async {
    expect(
      await errorFrom(clientReturning('<html>nope</html>')),
      isA<Malformed>(),
    );
  });

  test('a network failure is reported as no network', () async {
    final client = OpenAiClient(
      httpClient: MockClient(
        (_) async => throw http.ClientException('connection failed'),
      ),
      apiKeyProvider: () => 'sk-test',
    );
    final error = await errorFrom(client);
    expect(error, isA<NoNetwork>());
    expect(error.retryable, isTrue);
  });

  test('every error carries a message the user can act on', () {
    const errors = <ExtractionError>[
      RateLimited(3),
      CreditExhausted(),
      SpendLimitReached(),
      InvalidKey(),
      RegionUnsupported(),
      ServerError(500),
      NoNetwork(),
      Refused('x'),
      Truncated(),
      Malformed('x'),
      NoApiKey(),
    ];
    for (final error in errors) {
      // A message that only names the failure leaves the user with nothing to
      // do about it, which is how a retryable error becomes a dead end.
      expect(error.message, isNotEmpty);
      expect(
        error.message.endsWith('.'),
        isTrue,
        reason: '${error.runtimeType} is not a sentence',
      );
    }
  });

  // http.Response.body falls back to latin-1 when the server omits a charset.
  // JSON is UTF-8 by RFC 8259, so that fallback turns "hàng tháng" into mojibake
  // and the damage reads as a bad extraction rather than a decoding bug.
  test('a reply with no charset header still decodes Vietnamese', () async {
    final client = OpenAiClient(
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(responseWith(completeFields)),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
      apiKeyProvider: () => 'sk-test',
    );

    final fields = await client.extract(
      text: 'x',
      todayIso: '2026-08-15',
      locale: 'vi-VN',
    );
    expect(fields.billingCycleRaw, 'hàng tháng');
    expect(fields.amountRaw, '231.000đ');
  });

  test(
    'the default model is the current generation, not the deprecated nano',
    () {
      expect(OpenAiClient.defaultModel, 'gpt-5.6-luna');
      expect(OpenAiClient.defaultModel, isNot(contains('nano')));
    },
  );

  // `response_format` is the Chat Completions spelling and the most common
  // porting mistake; on the Responses API it is silently ignored, so the model
  // returns prose instead of JSON and nothing says why.
  test('the request uses the Responses API spelling of the schema', () async {
    Map<String, dynamic>? sent;
    final client = clientReturning(
      responseWith(completeFields),
      onRequest: (request) =>
          sent = jsonDecode(request.body) as Map<String, dynamic>,
    );
    await client.extract(text: 'x', todayIso: '2026-08-15', locale: 'vi-VN');

    expect(sent, isNotNull);
    expect(sent!.containsKey('response_format'), isFalse);

    final format = (sent!['text'] as Map)['format'] as Map;
    expect(format['type'], 'json_schema');
    expect(format['name'], ExtractionSchema.name);
    expect(format['strict'], isTrue);
    expect(format['schema'], isA<Map>());
  });

  test(
    'reasoning effort is pinned low so the bill stays predictable',
    () async {
      Map<String, dynamic>? sent;
      final client = clientReturning(
        responseWith(completeFields),
        onRequest: (request) =>
            sent = jsonDecode(request.body) as Map<String, dynamic>,
      );
      await client.extract(text: 'x', todayIso: '2026-08-15', locale: 'vi-VN');

      expect((sent!['reasoning'] as Map)['effort'], 'low');
      expect(sent!['max_output_tokens'], 800);
    },
  );

  test(
    'the prompt carries today and the locale, which the text cannot supply',
    () async {
      Map<String, dynamic>? sent;
      final client = clientReturning(
        responseWith(completeFields),
        onRequest: (request) =>
            sent = jsonDecode(request.body) as Map<String, dynamic>,
      );
      await client.extract(text: 'x', todayIso: '2026-08-15', locale: 'vi-VN');

      final system = (sent!['input'] as List).first as Map;
      expect(system['content'], contains('2026-08-15'));
      expect(system['content'], contains('vi-VN'));
    },
  );
}
