import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'extraction_error.dart';
import 'extraction_schema.dart';

/// Structured extraction against OpenAI's Responses API.
///
/// Sends TEXT, never the image. The screenshot is recognised on-device and the
/// user reviews and redacts the recognised lines before anything is
/// transmitted, which is what makes the redaction meaningful: there is no
/// original image on the wire for a missed region to leak through.
///
/// See product-spec.md sections 8.2bis and 8.4.
class OpenAiClient {
  /// Current-generation budget tier. Not gpt-5-nano: cheaper on paper but
  /// deprecated with a shutdown date and no Responses API support.
  static const String defaultModel = 'gpt-5.6-luna';

  final http.Client _http;
  final String? Function() _apiKeyProvider;

  final String model;
  final String baseUrl;

  OpenAiClient({
    required http.Client httpClient,
    required String? Function() apiKeyProvider,
    this.model = defaultModel,
    this.baseUrl = 'https://api.openai.com/v1',
  }) : _http = httpClient,
       // ignore: prefer_initializing_formals
       _apiKeyProvider = apiKeyProvider;

  /// Returns the parsed fields, or throws [ExtractionException].
  ///
  /// Every failure path carries an [ExtractionError] that already knows whether
  /// retrying could help, so no caller has to re-derive that from a status code.
  Future<ExtractedFields> extract({
    required String text,
    required String todayIso,
    required String locale,
  }) async {
    final key = _apiKeyProvider();
    if (key == null || key.isEmpty) {
      throw const ExtractionException(NoApiKey());
    }

    late final http.Response response;
    try {
      response = await _http.post(
        Uri.parse('$baseUrl/responses'),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_requestBody(text, todayIso, locale)),
      );
    } on http.ClientException {
      throw const ExtractionException(NoNetwork());
    } on SocketException {
      throw const ExtractionException(NoNetwork());
    } on HandshakeException {
      throw const ExtractionException(NoNetwork());
    }

    final body = _decodeBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ExtractionException(_parseError(response, body));
    }

    return _parseSuccess(body);
  }

  /// Decodes the body as UTF-8 explicitly.
  ///
  /// `http.Response.body` picks its codec from the response's `charset`
  /// parameter and falls back to **latin-1** when the server omits one. JSON is
  /// UTF-8 by RFC 8259, so that fallback mangles every Vietnamese character in
  /// a reply from a server that was merely terse about its headers, and the
  /// damage looks like a bad extraction rather than a decoding bug.
  String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      // Not valid UTF-8 at all: report it as malformed rather than pretending
      // some other encoding was meant.
      throw const ExtractionException(Malformed('response was not UTF-8'));
    }
  }

  Map<String, dynamic> _requestBody(
    String text,
    String todayIso,
    String locale,
  ) {
    return {
      'model': model,

      // Reasoning tokens bill as output tokens and are the largest line item
      // in a request that needs no reasoning. Left at the default this quietly
      // triples the cost of every extraction.
      'reasoning': {'effort': 'low'},

      // A truncated strict-JSON response is unparseable, not partially valid,
      // so the cap has to be paired with the status check in _parseSuccess.
      'max_output_tokens': 800,

      'input': [
        {
          'role': 'system',
          'content': ExtractionSchema.systemPrompt(todayIso, locale),
        },
        {'role': 'user', 'content': text},
      ],

      // Responses API spelling. `response_format` is the Chat Completions
      // equivalent and is the most common porting mistake; `name` is a sibling
      // of `schema`, not nested under a wrapper.
      'text': {
        'format': {
          'type': 'json_schema',
          'name': ExtractionSchema.name,
          'strict': true,
          'schema': jsonDecode(ExtractionSchema.json),
        },
      },
    };
  }

  ExtractionError _parseError(http.Response response, String body) {
    Map<String, dynamic>? error;
    try {
      final root = jsonDecode(body);
      if (root is Map<String, dynamic>) {
        final candidate = root['error'];
        if (candidate is Map<String, dynamic>) error = candidate;
      }
    } on FormatException {
      // A non-JSON error body is normal for a gateway failure. The status
      // still classifies it.
    }

    return ErrorMapper.map(
      response.statusCode,
      errorCode: error?['code'] as String?,
      errorType: error?['type'] as String?,
      retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''),
    );
  }

  ExtractedFields _parseSuccess(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const ExtractionException(Malformed('not json'));
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ExtractionException(Malformed('not json'));
    }

    // Check status before parsing: an incomplete response holds truncated JSON
    // that will not parse and must not be reported as a parse bug.
    if (decoded['status'] == 'incomplete') {
      throw const ExtractionException(Truncated());
    }

    final content = _firstContent(decoded);

    // A refusal does not honour the schema at all.
    final refusal = content?['refusal'];
    if (refusal is String) {
      throw ExtractionException(Refused(refusal));
    }

    final payload =
        (content?['text'] as String?) ?? (decoded['output_text'] as String?);
    if (payload == null) {
      throw const ExtractionException(Malformed('no output text'));
    }

    try {
      final fields = jsonDecode(payload);
      if (fields is! Map<String, dynamic>) {
        throw const FormatException('payload is not an object');
      }
      return ExtractedFields.fromJson(fields);
    } on ExtractionException {
      rethrow;
    } on FormatException catch (e) {
      throw ExtractionException(Malformed(e.message));
    } on TypeError catch (e) {
      // The reply parsed as JSON but had a field of the wrong shape.
      throw ExtractionException(Malformed(e.toString()));
    }
  }

  Map<String, dynamic>? _firstContent(Map<String, dynamic> root) {
    final output = root['output'];
    if (output is! List || output.isEmpty) return null;

    final first = output.first;
    if (first is! Map<String, dynamic>) return null;

    final content = first['content'];
    if (content is! List || content.isEmpty) return null;

    final firstContent = content.first;
    return firstContent is Map<String, dynamic> ? firstContent : null;
  }
}

class ExtractionException implements Exception {
  final ExtractionError error;

  const ExtractionException(this.error);

  String get message => error.message;

  bool get retryable => error.retryable;

  @override
  String toString() =>
      'ExtractionException(${error.runtimeType}): ${error.message}';
}
