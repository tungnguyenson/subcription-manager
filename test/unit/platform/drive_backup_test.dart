import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/drive_backup.dart';

/// Exercises the requests without a Google account anywhere near them.
///
/// This is where the bugs live. Whether the first write creates and the second
/// replaces, whether the query stays inside the hidden folder, and what a
/// revoked token turns into on screen are all decided here, and none of them
/// can be checked by signing in and watching it work once.
/// Keeps the real [DriveBackup.authHeaders], so a test can prove that a build
/// nobody has connected never reaches Google at all.
class _RealTokens extends DriveBackup {
  _RealTokens(http.Client client) : super(client: client);

  @override
  bool get isSupported => true;
}

class _TestDrive extends DriveBackup {
  _TestDrive(http.Client client) : super(client: client);

  /// Pinned rather than inherited so that these stay about the requests. The
  /// real getter follows the client id, and a run that blanked it with
  /// `--dart-define` would short-circuit every method below before it reached
  /// the network.
  @override
  bool get isSupported => true;

  /// Null stands for an account that cannot supply a token any more.
  Map<String, String>? headers = const {'Authorization': 'Bearer test'};

  @override
  Future<Map<String, String>?> authHeaders() async => headers;
}

/// Counts the calls into the plugin, and fails the first one.
class _CountingStart extends _TestDrive {
  _CountingStart(super.client);

  int starts = 0;
  bool fail = true;

  @override
  Future<void> initializePlugin() async {
    starts++;
    if (fail) {
      fail = false;
      throw StateError('play services busy');
    }
  }
}

void main() {
  /// Every request the fake saw, in order.
  late List<http.Request> seen;

  /// Builds a client that answers the list query with [files], and everything
  /// else with [reply].
  MockClient serving({
    List<Map<String, Object?>> files = const [],
    int listStatus = 200,
    http.Response Function(http.Request)? reply,
  }) => MockClient((request) async {
    seen.add(request);
    final isList =
        request.method == 'GET' && !request.url.path.contains('/upload/');
    if (isList && !request.url.queryParameters.containsKey('alt')) {
      return listStatus == 200
          ? http.Response(jsonEncode({'files': files}), 200)
          : http.Response('{}', listStatus);
    }
    return reply?.call(request) ?? http.Response('{}', 200);
  });

  setUp(() => seen = []);

  http.Request? requestTo(String method, String fragment) => seen
      .where((r) => r.method == method && r.url.toString().contains(fragment))
      .firstOrNull;

  group('the shipped client id', () {
    /// The id lives in the source, so a plain `flutter run` offers the Drive
    /// row. It used to arrive by `--dart-define`, which meant every command
    /// that forgot the flag dropped the row with nothing said about it.
    ///
    /// This test runs with no dart-defines at all, which is exactly the case
    /// that used to be broken.
    test('a build with no dart-define still offers the row', () {
      expect(DriveBackup.serverClientId, isNotEmpty);
    });

    /// A truncated or mistyped id passes [DriveBackup.isSupported] and then
    /// fails on a real phone as `clientConfigurationError`, which the docs
    /// call the hardest failure here to reproduce at a desk. Shape is all a
    /// test can check without a Google account, and shape is what an edit
    /// during a project rotation gets wrong.
    test('the shipped id has the shape Google issues', () {
      expect(
        DriveBackup.serverClientId,
        matches(
          RegExp(r'^\d{6,}-[a-z0-9]{20,}\.apps\.googleusercontent\.com$'),
        ),
      );
    });
  });

  group('the lookup that runs before every request', () {
    /// The lookup throws its own exception type, and for a long time nothing
    /// caught it: it fell through to the catch-all that prints the error, and
    /// `_HttpProblem` has no `toString`. So a user who had removed this app in
    /// their Drive settings was told `Instance of '_HttpProblem'` instead of
    /// being offered the one tap that fixes it.
    ///
    /// Both verbs run the same lookup first, so both are on trial here.
    test('a revoked authorization is an account to reconnect, not a bug', () {
      for (final status in [401, 403]) {
        expect(
          _TestDrive(serving(listStatus: status)).save('{}'),
          completion(
            isA<CloudResult>().having(
              (r) => r.state,
              'state',
              CloudState.signedOut,
            ),
          ),
          reason: 'save, $status',
        );
        expect(
          _TestDrive(serving(listStatus: status)).latest(),
          completion(
            isA<CloudFetch>().having(
              (f) => f.state,
              'state',
              CloudState.signedOut,
            ),
          ),
          reason: 'restore, $status',
        );
      }
    });

    /// Anything else really is a failure, but it still has to name the status
    /// rather than leak the exception's class name. `app.dart` prints this
    /// string to the user on a failed restore.
    test('any other answer names the status rather than the class', () async {
      final saved = await _TestDrive(serving(listStatus: 500)).save('{}');
      final read = await _TestDrive(serving(listStatus: 500)).latest();

      expect(saved.state, CloudState.failed);
      expect(saved.detail, 'Drive answered 500');
      expect(read.state, CloudState.failed);
      expect(read.detail, 'Drive answered 500');
    });
  });

  group('starting the plugin', () {
    /// A rejected future is not null, so memoizing one with a bare `??=` hands
    /// the same failure to every later call. The user taps Connect, it fails,
    /// and the button is dead until the app is force-quit.
    test('a failed start is not remembered as the answer', () async {
      final drive = _CountingStart(serving());

      await expectLater(drive.start(), throwsA(isA<StateError>()));
      await drive.start();

      expect(drive.starts, 2);
    });

    /// The other half of the same memo: a start that worked is not repeated,
    /// which is what makes it a memo at all.
    test('a start that worked is not repeated', () async {
      final drive = _CountingStart(serving())..fail = false;

      await drive.start();
      await drive.start();

      expect(drive.starts, 1);
    });
  });

  // The reason this whole class remembers the account itself. The plugin's
  // "lightweight" sign-in makes a second call on Android whenever the first
  // finds no already-authorized account, and that second call opens the
  // one-tap sheet over any Google account on the phone. Reaching for it at
  // launch asked people who never wanted cloud backup to sign in to Google.
  group('before anyone has connected', () {
    /// The real token path rather than the fake one every other group uses:
    /// what is on trial here is whether Google gets touched at all.
    DriveBackup untouched(http.Client client) => _RealTokens(client);

    test('a write asks nothing of anyone', () async {
      final result = await untouched(serving()).save('{}');

      expect(result.state, CloudState.disconnected);
      expect(seen, isEmpty);
    });

    test('a read asks nothing of anyone', () async {
      final fetch = await untouched(serving()).latest();

      expect(fetch.state, CloudState.disconnected);
      expect(seen, isEmpty);
    });

    // Taking an account back up out of the app's own database is the entire
    // startup path, and it is not allowed to go anywhere.
    test('resuming an account reaches no network either', () async {
      final drive = untouched(serving())..resume('someone@gmail.com');

      expect(drive.needsAccount, isFalse);
      expect(drive.account, 'someone@gmail.com');
      expect(seen, isEmpty);
    });

    // Connected but tokenless is an authorization that lapsed or was revoked
    // in the user's Drive settings, and the fix is one tap. Reporting it as
    // `disconnected` would drop the account off a screen still showing it.
    test('a resumed account with no token asks to reconnect', () async {
      final drive = _TestDrive(serving())
        ..resume('someone@gmail.com')
        ..headers = null;

      expect((await drive.save('{}')).state, CloudState.signedOut);
    });
  });

  group('finding the copy', () {
    // Without `spaces` Drive searches My Drive, where this app has neither
    // permission nor business.
    test('the query never leaves the hidden folder', () async {
      await _TestDrive(serving()).save('{}');

      final query = seen.first.url.queryParameters;
      expect(query['spaces'], 'appDataFolder');
      expect(query['q'], contains(DriveBackup.fileName));
    });
  });

  group('writing', () {
    // The metadata and the bytes have to arrive together: the parent is what
    // puts the file in the hidden folder, and a file uploaded without it
    // lands in My Drive, which this app cannot write to.
    test('the first write creates the file inside the folder', () async {
      final result = await _TestDrive(serving()).save('{"items":[]}');

      expect(result.state, CloudState.saved);
      final post = requestTo('POST', 'uploadType=multipart');
      expect(post, isNotNull);
      expect(post!.body, contains('"parents":["appDataFolder"]'));
      expect(post.body, contains('{"items":[]}'));
    });

    // Posting again would leave two files with one name in the folder, and
    // the next read would take whichever Drive listed first.
    test('a second write replaces the file rather than adding one', () async {
      final drive = _TestDrive(
        serving(
          files: [
            {'id': 'file-1', 'modifiedTime': '2026-08-27T12:52:00.000Z'},
          ],
        ),
      );

      final result = await drive.save('{"items":[1]}');

      expect(result.state, CloudState.saved);
      expect(requestTo('POST', 'upload'), isNull, reason: 'no second file');
      final patch = requestTo('PATCH', 'file-1');
      expect(patch, isNotNull);
      expect(patch!.body, '{"items":[1]}');
    });

    // The user revoked the token, or removed this app in their Drive
    // settings. Both are theirs to fix, and `Could not save` would send them
    // hunting for a bug in the app instead.
    test('a refused token reads as an account to reconnect', () async {
      final drive = _TestDrive(
        serving(reply: (_) => http.Response('nope', 403)),
      );

      expect((await drive.save('{}')).state, CloudState.signedOut);
    });

    test('an unexplained status is a failure, not a revoked account', () async {
      final drive = _TestDrive(
        serving(reply: (_) => http.Response('boom', 500)),
      );

      final result = await drive.save('{}');
      expect(result.state, CloudState.failed);
      expect(result.detail, contains('500'));
    });

    // Nothing broke; nobody has connected an account. Saying `Could not save`
    // would report a fault at a user who was never asked.
    test('no account is disconnected rather than failed', () async {
      final drive = _TestDrive(serving())..headers = null;

      expect((await drive.save('{}')).state, CloudState.disconnected);
      expect(seen, isEmpty, reason: 'nothing to ask Drive without a token');
    });

    // The account is remembered by the app; the write only needs a token.
    test('a resumed account writes without signing in again', () async {
      final drive = _TestDrive(serving())..resume('someone@gmail.com');

      expect((await drive.save('{}')).state, CloudState.saved);
    });
  });

  group('reading it back', () {
    test('an empty folder is missing, not an error', () async {
      expect((await _TestDrive(serving()).latest()).state, CloudState.missing);
    });

    test('the copy comes back with the moment it was written', () async {
      final drive = _TestDrive(
        serving(
          files: [
            {'id': 'file-1', 'modifiedTime': '2026-08-27T12:52:00.000Z'},
          ],
          reply: (_) => http.Response('{"items":[]}', 200),
        ),
      );

      final fetch = await drive.latest();

      expect(fetch.state, CloudState.saved);
      expect(fetch.copy?.contents, '{"items":[]}');
      expect(fetch.copy?.changedAt, DateTime.utc(2026, 8, 27, 12, 52));
    });

    // A download that came back with nothing would reach the format check as
    // "not a Subdock backup", which blames the user's copy for the network.
    test('an empty download says so rather than blaming the file', () async {
      final drive = _TestDrive(
        serving(
          files: [
            {'id': 'file-1'},
          ],
          reply: (_) => http.Response('', 200),
        ),
      );

      final fetch = await drive.latest();
      expect(fetch.state, CloudState.failed);
      expect(fetch.detail, contains('empty'));
    });
  });
}
