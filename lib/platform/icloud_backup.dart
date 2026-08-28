import 'dart:async';

import 'package:icloud_storage_plus/icloud_storage.dart';

import 'package:subdock/platform/cloud_backup.dart';

/// Keeps a copy of the backup in the user's own iCloud.
///
/// **Backup, one direction, not sync.** The app writes and never reads except
/// when the user asks to restore. Two-way sync would need conflict resolution
/// between devices, which is a different feature with a different cost; see
/// `docs/backup-and-sync.md` section 6.3 for where that line is drawn and why.
///
/// The user's own iCloud rather than a server of ours: no account to create,
/// no backend to run, nothing worth stealing in one place, and it works the
/// moment they are signed into the phone they already own.
///
/// This exists because of a specific hole. The database is inside the iPhone's
/// own backup already, but iOS will only give that back by restoring the whole
/// phone, so the copy is useless to anyone who just wants their list. A file of
/// its own in the app's iCloud container comes back on its own.
///
/// A class rather than top-level functions so a test can put a fake in its
/// place, the same as [BackupFiles] and [NotificationScheduler].
class ICloudBackup extends CloudBackup {
  /// Must match `com.apple.developer.icloud-container-identifiers` in
  /// `ios/Runner/Runner.entitlements`. A mismatch is not a build error: the
  /// container simply does not resolve and every call comes back
  /// [CloudState.signedOut], which reads on screen as the user's fault.
  static const String containerId = 'iCloud.space.subdock.subdock';

  /// One file, overwritten. Not a dated series: the container is visible in
  /// the Files app, and a folder that grows a file every time the user edits
  /// an item is a folder they will eventually delete in irritation. The dated
  /// copies are the ones they save by hand through the share sheet.
  static const String fileName = 'subdock-latest.json';

  ICloudBackup();

  /// Always true: this class is only ever built on iOS. Which platform gets
  /// which cloud is decided once, where the app is assembled, rather than
  /// asked again inside every method.
  @override
  bool get isSupported => true;

  @override
  CloudKind get kind => CloudKind.icloud;

  /// Writes [contents] over the single file in the container.
  ///
  /// Never throws. Every failure comes back as a [CloudResult] the screen can
  /// print, because this runs on a timer with nobody watching: an exception
  /// here would be swallowed by the caller's `unawaited` and the user would go
  /// on believing they are backed up.
  ///
  /// Written in place rather than staged to a temporary file and copied in.
  /// The backup is tens of kilobytes, which is the size the in-place API is
  /// for, and it removes a file this app used to leave in the temporary
  /// directory after every edit.
  @override
  Future<CloudResult> save(String contents) async {
    if (!isSupported) return CloudResult.unsupported;

    try {
      await ICloudStorage.writeInPlace(
        containerId: containerId,
        relativePath: fileName,
        contents: contents,
      );
      return const CloudResult(CloudState.saved);
    } on ICloudContainerAccessException {
      // The one failure the user can act on, and the one the app must not
      // dress up as a bug: signed out of iCloud, iCloud Drive off, or
      // permission refused for this app.
      return const CloudResult(CloudState.signedOut);
    } on ICloudOperationException catch (error) {
      return CloudResult(CloudState.failed, detail: error.message);
    } on Exception catch (error) {
      return CloudResult(CloudState.failed, detail: '$error');
    }
  }

  /// How long a read is given before the app stops waiting on it.
  ///
  /// A file this size is a few tens of kilobytes, so anything past this is a
  /// network that is not going to finish. The user is holding the phone
  /// waiting for an answer, and no answer at all is the worst one.
  ///
  /// Needed even though the read is a single await: a coordinated open on a
  /// file the phone has not downloaded yet blocks until iCloud hands the bytes
  /// over, and iCloud is under no obligation to hurry.
  static const Duration _fetchTimeout = Duration(seconds: 20);

  /// Reads back the single file in the container, if it is there.
  ///
  /// The one read this class does, and only ever because the user asked to
  /// restore. Nothing here runs on a timer: that would be the first half of
  /// two-way sync, which is a different feature with a different cost. See
  /// `docs/backup-and-sync.md` section 6.3.
  @override
  Future<CloudFetch> latest() async {
    if (!isSupported) return const CloudFetch(CloudState.unsupported);

    try {
      // `gather` runs a metadata query; `listContents` and `getItemMetadata`
      // read the local filesystem. The difference decides this call. Whoever
      // opens this screen has usually just reinstalled or changed phone, and
      // on a device that has never seen the container the file exists only as
      // a promise the metadata query knows about and the filesystem does not
      // yet. Asking the filesystem would answer `missing` to exactly the
      // person this feature is for.
      final gathered = await ICloudStorage.gather(containerId: containerId);
      final match = gathered.files
          .where((file) => file.relativePath == fileName)
          .firstOrNull;
      if (match == null) return const CloudFetch(CloudState.missing);

      final contents = await ICloudStorage.readInPlace(
        containerId: containerId,
        relativePath: fileName,
      ).timeout(_fetchTimeout);

      // An empty read would reach the format check as "not a Subdock backup",
      // which blames the user's file for a download that came back with
      // nothing.
      if (contents.isEmpty) {
        return const CloudFetch(
          CloudState.failed,
          detail: 'the copy came back empty',
        );
      }

      return CloudFetch(
        CloudState.saved,
        copy: CloudCopy(contents: contents, changedAt: match.contentChangeDate),
      );
    } on TimeoutException {
      return const CloudFetch(
        CloudState.failed,
        detail: 'the copy did not finish downloading',
      );
    } on ICloudItemNotFoundException {
      // The metadata query saw it and the read did not. A file deleted from
      // another device between the two calls lands here, and `missing` is the
      // honest answer: there is nothing to restore.
      return const CloudFetch(CloudState.missing);
    } on ICloudContainerAccessException {
      return const CloudFetch(CloudState.signedOut);
    } on ICloudOperationException catch (error) {
      return CloudFetch(CloudState.failed, detail: error.message);
    } on Exception catch (error) {
      return CloudFetch(CloudState.failed, detail: '$error');
    }
  }
}
