import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'package:subdock/platform/cloud_backup.dart';

/// Keeps a copy of the backup in the user's own Google Drive.
///
/// The Android answer to the same hole iCloud fills on iOS. Android's own
/// system backup does carry the database to a new phone, but the app cannot
/// see whether it ever ran, cannot ask it to run, and cannot get the data back
/// on demand: it only lands when the app is reinstalled. So the list is safe
/// in a way nobody can check, which is not a promise this app is willing to
/// print on a screen.
///
/// The user's own Drive rather than a server of ours: no account of ours to
/// create, no backend to run, nothing worth stealing in one place. What it
/// costs, and iCloud does not, is one sign-in. There is no way around that;
/// Apple hands an app its container, Google asks the user first.
///
/// **The App Data folder, not a folder in My Drive.** It is hidden from Drive's
/// own interface and from every other app, so nothing here appears among the
/// user's documents and nothing else can read it. They can still delete it
/// from Drive's connected-apps settings, which is theirs to do, and the
/// staleness warning on the Settings screen is what notices when they have.
class DriveBackup extends CloudBackup {
  /// The narrowest scope Google publishes for this: it opens the app's own
  /// hidden folder and nothing else in the user's Drive.
  ///
  /// It is classified non-sensitive, which is the whole reason this feature is
  /// affordable: no verification review, no annual security assessment, and no
  /// `Google hasn't verified this app` screen in front of the user. Widening
  /// it to `drive.file` or `drive` throws all three of those away.
  static const String scope = 'https://www.googleapis.com/auth/drive.appdata';

  /// One file, overwritten. Not a dated series: this is the copy that has to
  /// match the list, and a folder that grows a file per edit is a quota the
  /// user pays for to hold versions no screen in the app can offer them.
  static const String fileName = 'subdock-latest.json';

  /// The OAuth client the Android sign-in identifies itself with, supplied at
  /// build time by `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
  ///
  /// Not a secret, and not hardcoded either. A build without it is a build
  /// where this whole channel reports [isSupported] false, so a checkout with
  /// no Google project behind it still compiles, still runs, and simply does
  /// not offer the row. That is better than a row that opens a sign-in sheet
  /// and fails with a configuration error the user cannot act on.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  final http.Client _client;

  DriveBackup({http.Client? client}) : _client = client ?? http.Client();

  /// The account the app was told it is attached to, seeded from storage.
  ///
  /// Not read back out of the plugin, and that is the whole point. Asking the
  /// plugin who is signed in means a sign-in call, and on Android that call
  /// can open a sheet. See [CloudStore] for the full reason.
  String? _account;

  Future<void>? _started;

  @override
  bool get isSupported => _serverClientId.isNotEmpty;

  @override
  CloudKind get kind => CloudKind.drive;

  @override
  bool get needsAccount => _account == null;

  @override
  String? get account => _account;

  /// Takes back up an account attached in an earlier run, without reaching
  /// Google at all.
  ///
  /// The whole startup path. Nothing here authenticates, nothing here can show
  /// anything, and a user who has never connected gets no Google traffic
  /// whatsoever because the caller passes null.
  @override
  void resume(String? account) => _account = account;

  /// How long any one request is given before the app stops waiting.
  ///
  /// The file is tens of kilobytes, so past this it is a network that is not
  /// going to finish. The write runs unattended and would otherwise hold its
  /// slot forever; the read has somebody holding the phone, and no answer at
  /// all is the worst one.
  static const Duration _timeout = Duration(seconds: 20);

  Future<void> _start() => _started ??= GoogleSignIn.instance.initialize(
    serverClientId: _serverClientId,
  );

  @override
  Future<CloudResult> connect() async {
    if (!isSupported) return CloudResult.unsupported;

    try {
      await _start();
      final user = await GoogleSignIn.instance.authenticate(
        scopeHint: const [scope],
      );
      // Authentication and authorization are two steps, and the hint above is
      // only a hint: a platform that ignored it leaves the account signed in
      // with no access to the folder. Asking outright is the only way to know.
      await user.authorizationClient.authorizeScopes(const [scope]);
      _account = user.email;
      return const CloudResult(CloudState.saved);
    } on GoogleSignInException catch (error) {
      return _fromSignIn(error);
    } on Exception catch (error) {
      return CloudResult(CloudState.failed, detail: '$error');
    }
  }

  @override
  Future<void> disconnect() async {
    _account = null;
    if (!isSupported) return;
    try {
      await GoogleSignIn.instance.signOut();
    } on Exception {
      // Nothing to tell the user. The account is detached in this app either
      // way, which is what they asked for; a failure to also tell Google is
      // not something they can act on.
    }
  }

  /// Turns a sign-in failure into something the screen can print.
  ///
  /// Backing out of the sheet is [CloudState.disconnected], not a failure:
  /// declining an offer is an answer, and reporting it in red would tell the
  /// user something went wrong when they are the thing that went right.
  ///
  /// A configuration error keeps its description, and that is deliberate. It
  /// is what a missing SHA-1 fingerprint comes back as, including the one Play
  /// generates when it re-signs the app, and that failure reaches only users
  /// who installed from the Store. Swallowing the text would leave the one
  /// clue at the one moment it cannot be reproduced at a desk.
  static CloudResult _fromSignIn(GoogleSignInException error) =>
      switch (error.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => const CloudResult(
          CloudState.disconnected,
        ),
        _ => CloudResult(
          CloudState.failed,
          detail: error.description ?? error.code.name,
        ),
      };

  /// The bearer header for a request, or null if no token can be had silently.
  ///
  /// Asked of the instance-wide authorization client rather than of a signed-in
  /// user object, deliberately. This one hands back a token for scopes already
  /// granted and returns null otherwise; it never authenticates and never
  /// opens anything. Holding a user object instead would mean signing in to
  /// get one, which is the call that ambushes people at launch.
  ///
  /// Overridable so a test can exercise the requests below against a fake HTTP
  /// client with no Google account anywhere near it. That is where the bugs
  /// live: which verb creates versus updates, and what a missing file does.
  @visibleForTesting
  Future<Map<String, String>?> authHeaders() async {
    if (_account == null) return null;
    await _start();
    return GoogleSignIn.instance.authorizationClient.authorizationHeaders(
      const [scope],
    );
  }

  /// What a missing token means, which depends on whether there was ever an
  /// account.
  ///
  /// Never connected is an offer nobody took up. Connected but tokenless is an
  /// authorization that lapsed or was revoked in the user's Drive settings,
  /// and the fix is one tap. Reporting the second as the first would drop the
  /// account name off a screen that is still showing it.
  CloudState get _noToken =>
      _account == null ? CloudState.disconnected : CloudState.signedOut;

  static const String _files = 'https://www.googleapis.com/drive/v3/files';
  static const String _upload =
      'https://www.googleapis.com/upload/drive/v3/files';

  @override
  Future<CloudResult> save(String contents) async {
    if (!isSupported) return CloudResult.unsupported;

    try {
      final headers = await authHeaders();
      if (headers == null) return CloudResult(_noToken);

      final existing = await _findId(headers);
      final response = existing == null
          ? await _create(headers, contents)
          : await _replace(headers, existing, contents);

      return response.statusCode >= 200 && response.statusCode < 300
          ? const CloudResult(CloudState.saved)
          : _httpProblem(response).toResult();
    } on TimeoutException {
      return const CloudResult(
        CloudState.failed,
        detail: 'the copy did not finish uploading',
      );
    } on Exception catch (error) {
      return CloudResult(CloudState.failed, detail: '$error');
    }
  }

  @override
  Future<CloudFetch> latest() async {
    if (!isSupported) return const CloudFetch(CloudState.unsupported);

    try {
      final headers = await authHeaders();
      if (headers == null) return CloudFetch(_noToken);

      final found = await _find(headers);
      if (found == null) return const CloudFetch(CloudState.missing);

      final response = await _client
          .get(Uri.parse('$_files/${found.id}?alt=media'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpProblem(response).toFetch();
      }

      // Decoded from bytes rather than `response.body`, which would guess the
      // charset off a header Drive does not always send. The file is written
      // as UTF-8 by this app and read back as UTF-8 here.
      final contents = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (contents.isEmpty) {
        return const CloudFetch(
          CloudState.failed,
          detail: 'the copy came back empty',
        );
      }

      return CloudFetch(
        CloudState.saved,
        copy: CloudCopy(contents: contents, changedAt: found.changedAt),
      );
    } on TimeoutException {
      return const CloudFetch(
        CloudState.failed,
        detail: 'the copy did not finish downloading',
      );
    } on Exception catch (error) {
      return CloudFetch(CloudState.failed, detail: '$error');
    }
  }

  Future<String?> _findId(Map<String, String> headers) async =>
      (await _find(headers))?.id;

  /// Looks the single file up by name inside the hidden folder.
  ///
  /// `spaces=appDataFolder` is what keeps the query inside it. Without that
  /// parameter Drive searches My Drive, where this app has no permission to
  /// look and no business looking.
  Future<_DriveFile?> _find(Map<String, String> headers) async {
    final query = Uri.parse(_files).replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': "name = '$fileName'",
        'fields': 'files(id,modifiedTime)',
        'pageSize': '10',
      },
    );

    final response = await _client
        .get(query, headers: headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _HttpProblem(response.statusCode);
    }

    final body = jsonDecode(response.body);
    final files = body is Map<String, dynamic> ? body['files'] : null;
    if (files is! List || files.isEmpty) return null;

    final first = files.first;
    if (first is! Map<String, dynamic>) return null;
    final id = first['id'];
    if (id is! String) return null;

    return _DriveFile(
      id: id,
      changedAt: DateTime.tryParse('${first['modifiedTime']}'),
    );
  }

  /// The first write, which is also what creates the folder.
  ///
  /// A multipart body because the metadata and the contents have to arrive
  /// together: the name and the parent are what put the file inside the hidden
  /// folder, and a file uploaded without them lands in My Drive, which this
  /// app has no permission to write to.
  Future<http.Response> _create(
    Map<String, String> headers,
    String contents,
  ) async {
    const boundary = 'subdock-boundary';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': const ['appDataFolder'],
    });

    final body =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$contents\r\n'
        '--$boundary--';

    return _client
        .post(
          Uri.parse('$_upload?uploadType=multipart'),
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: utf8.encode(body),
        )
        .timeout(_timeout);
  }

  /// Every write after the first. `PATCH` on the id rather than another
  /// `POST`: posting again would leave a second file with the same name in the
  /// folder, and the next read would pick whichever one Drive listed first.
  Future<http.Response> _replace(
    Map<String, String> headers,
    String id,
    String contents,
  ) => _client
      .patch(
        Uri.parse('$_upload/$id?uploadType=media'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: utf8.encode(contents),
      )
      .timeout(_timeout);

  static _HttpProblem _httpProblem(http.Response response) =>
      _HttpProblem(response.statusCode);
}

/// The one file, as Drive describes it.
class _DriveFile {
  final String id;
  final DateTime? changedAt;

  const _DriveFile({required this.id, this.changedAt});
}

/// A status code, turned into the two states the screen tells apart.
///
/// 401 and 403 are the ones the user can act on: the token was revoked, or
/// they removed this app from their Drive settings. Both are fixed by
/// connecting again, and both would be a lie dressed as a bug if reported as
/// `Could not save`.
class _HttpProblem implements Exception {
  final int status;

  const _HttpProblem(this.status);

  bool get isAccess => status == 401 || status == 403;

  CloudResult toResult() => isAccess
      ? const CloudResult(CloudState.signedOut)
      : CloudResult(CloudState.failed, detail: 'Drive answered $status');

  CloudFetch toFetch() => isAccess
      ? const CloudFetch(CloudState.signedOut)
      : CloudFetch(CloudState.failed, detail: 'Drive answered $status');
}
