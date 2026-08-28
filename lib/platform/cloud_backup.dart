import 'package:flutter/foundation.dart' show immutable;

/// How the last write to the user's own cloud went.
enum CloudState {
  /// The file is there. This is the only value that means the list is safe
  /// without the user having done anything.
  saved,

  /// Reached the cloud and it said no: not signed in, iCloud Drive switched
  /// off, or permission refused for this app. The user can fix it; the app
  /// cannot, and must not pretend the list is covered meanwhile.
  signedOut,

  /// Tried and something else went wrong. Reported rather than swallowed: a
  /// backup that quietly stopped working is worse than one that never started,
  /// because the user believes in it.
  failed,

  /// Reached the cloud and there is nothing there. Only ever comes back from
  /// a read: a write either lands or fails.
  missing,

  /// Nothing has been attempted yet this run.
  idle,

  /// The channel works on this platform, but no account is attached to it yet.
  ///
  /// Its own value rather than folding into [signedOut], because the two ask
  /// the user for different things. `signedOut` is something that broke and
  /// wants fixing; this is an offer nobody has taken up, and reporting it as
  /// a fault would accuse the user of breaking a thing they never turned on.
  disconnected,

  /// This platform has no cloud the app writes to. Android is here, and it is
  /// not a gap: the system already backs the database up and hands it to the
  /// next phone, which is what this class exists to add on iOS.
  unsupported,
}

/// The outcome of one attempt, with the reason attached when it failed.
@immutable
class CloudResult {
  final CloudState state;

  /// The platform's own message, for [CloudState.failed] only. Kept so a
  /// failure nobody predicted can still be read off the screen instead of
  /// being reported as a shrug.
  final String? detail;

  const CloudResult(this.state, {this.detail});

  static const idle = CloudResult(CloudState.idle);
  static const unsupported = CloudResult(CloudState.unsupported);
}

/// A copy found in the cloud, already read.
@immutable
class CloudCopy {
  final String contents;

  /// When the copy was last written, off the file itself rather than off the
  /// backup inside it.
  ///
  /// Nullable because the metadata query is allowed to come back without it,
  /// and a date invented here would be indistinguishable on screen from one
  /// the file actually carries. Nothing displays it today; it is kept because
  /// the confirmation is the place it belongs, and reading it back off the
  /// file is the only honest source for it.
  final DateTime? changedAt;

  const CloudCopy({required this.contents, this.changedAt});
}

/// What a read found.
@immutable
class CloudFetch {
  final CloudState state;
  final CloudCopy? copy;
  final String? detail;

  const CloudFetch(this.state, {this.copy, this.detail});
}

/// Which cloud the app writes to on this platform.
///
/// The two are not interchangeable on screen. iCloud is already signed in and
/// needs no account row; Drive has one, and a user with two Google accounts
/// has two different backups. Naming the cloud is also the difference between
/// `Sign in to iCloud` and `Reconnect your account`, and sending someone to
/// the wrong one of those is sending them to a settings page that will not
/// help them.
enum CloudKind { none, icloud, drive }

/// One place the app keeps a copy of the list, outside the device.
///
/// Two of these exist and they are not the same shape. iCloud is already
/// signed in on the phone, so the app writes without asking anyone anything.
/// Google Drive needs an account attached first, once, by the user. The extra
/// members below are what that difference costs, and they default to doing
/// nothing so the channel that has no account never has to mention one.
///
/// One direction, not sync. Every implementation writes, and reads only when
/// the user asks to restore. Reading on a timer would be the first half of
/// two-way sync, which is a different feature with a different cost; see
/// `docs/backup-and-sync.md` section 6.3.
///
/// A class rather than top-level functions so a test can put a fake in its
/// place, the same as `BackupFiles` and `NotificationScheduler`.
abstract class CloudBackup {
  const CloudBackup();

  /// Whether this build writes to a cloud at all. False hides the row rather
  /// than showing one that reads `Not available`, which would report a gap
  /// where there is none.
  bool get isSupported;

  /// Which cloud this is, for the wording on the one screen that names it.
  ///
  /// Asked of the channel rather than worked out from `defaultTargetPlatform`
  /// at the call site: a test that puts a fake in place on an Android emulator
  /// would otherwise be told it is looking at Drive while the fake stands in
  /// for iCloud, and every sentence on the page would be the wrong one.
  CloudKind get kind => CloudKind.none;

  /// Whether the user has to attach an account before anything is written.
  ///
  /// False on iCloud, where the phone is already signed in and there is
  /// nothing to ask. True on Drive until they have connected one, which is
  /// why the screen needs to tell the two apart rather than printing `Never`
  /// at somebody who was never offered the chance to say yes.
  bool get needsAccount => false;

  /// The account copies go to, for the one screen that names it.
  ///
  /// Null where there is no account to name. It matters on Drive because a
  /// user with two Google accounts has two different backups, and which one
  /// they are looking at is not something they can work out from a date.
  String? get account => null;

  /// Attaches an account, showing whatever the platform shows.
  ///
  /// Only ever from a tap. Anything that puts a sign-in sheet in front of
  /// someone who did not ask for it is a bug, not a feature.
  Future<CloudResult> connect() async => CloudResult.unsupported;

  /// Takes back up an account attached in an earlier run.
  ///
  /// Deliberately not a `Future` and deliberately not a call to the platform:
  /// this runs at launch, and the one thing it must never do is put a sign-in
  /// sheet in front of somebody who has not asked for cloud backup. The caller
  /// hands over what it read from its own database; nothing here goes out.
  ///
  /// Does nothing on a channel with no account to attach.
  void resume(String? account) {}

  /// Detaches the account. The copy already in the cloud stays where it is:
  /// deleting somebody's backup on their behalf, because they turned a switch
  /// off, is not a decision this app gets to make.
  Future<void> disconnect() async {}

  /// Writes [contents] over the single copy.
  ///
  /// Never throws. Every failure comes back as a [CloudResult] the screen can
  /// print, because this runs on a timer with nobody watching: an exception
  /// here would be swallowed by the caller's `unawaited` and the user would go
  /// on believing they are backed up.
  Future<CloudResult> save(String contents);

  /// Reads the copy back, if there is one.
  Future<CloudFetch> latest();
}

/// The answer on a platform the app writes no cloud copy for.
///
/// Everything reports [CloudState.unsupported], which is what takes the row
/// off the Settings screen entirely.
class NoCloud extends CloudBackup {
  const NoCloud();

  @override
  bool get isSupported => false;

  @override
  Future<CloudResult> save(String contents) async => CloudResult.unsupported;

  @override
  Future<CloudFetch> latest() async => const CloudFetch(CloudState.unsupported);
}
