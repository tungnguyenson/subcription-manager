import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform, immutable;
import 'package:flutter/services.dart' show PlatformException;
import 'package:icloud_storage/icloud_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  /// backup inside it. Shown on the confirmation so someone with an old phone
  /// still switched on can see which copy they are about to take.
  final DateTime changedAt;

  const CloudCopy({required this.contents, required this.changedAt});
}

/// What a read found.
@immutable
class CloudFetch {
  final CloudState state;
  final CloudCopy? copy;
  final String? detail;

  const CloudFetch(this.state, {this.copy, this.detail});
}

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
class CloudBackup {
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

  final TargetPlatform _platform;

  CloudBackup(this._platform);

  /// Android is deliberately not covered. Its system backup already carries
  /// the database to a new phone by itself, which is the thing iOS will not
  /// do; adding a second mechanism there would duplicate the platform without
  /// making anything safer. What the app cannot do is tell the user whether
  /// that system backup ever ran, and the Settings note says so.
  bool get isSupported => _platform == TargetPlatform.iOS;

  /// Writes [contents] over the single file in the container.
  ///
  /// Never throws. Every failure comes back as a [CloudResult] the screen can
  /// print, because this runs on a timer with nobody watching: an exception
  /// here would be swallowed by the caller's `unawaited` and the user would go
  /// on believing they are backed up.
  Future<CloudResult> save(String contents) async {
    if (!isSupported) return CloudResult.unsupported;

    try {
      final staged = await _stage(contents);
      await ICloudStorage.upload(
        containerId: containerId,
        filePath: staged.path,
        destinationRelativePath: fileName,
      );
      return const CloudResult(CloudState.saved);
    } on PlatformException catch (error) {
      // The one failure the user can act on, and the one the app must not
      // dress up as a bug: signed out of iCloud, iCloud Drive off, or
      // permission refused for this app.
      if (error.code == PlatformExceptionCode.iCloudConnectionOrPermission) {
        return const CloudResult(CloudState.signedOut);
      }
      return CloudResult(CloudState.failed, detail: error.message);
    } on Exception catch (error) {
      return CloudResult(CloudState.failed, detail: '$error');
    }
  }

  /// How long a download is given before the app stops waiting on it.
  ///
  /// A file this size is a few tens of kilobytes, so anything past this is a
  /// network that is not going to finish. The user is holding the phone
  /// waiting for an answer, and no answer at all is the worst one.
  static const Duration _fetchTimeout = Duration(seconds: 20);

  /// Reads back the single file in the container, if it is there.
  ///
  /// The one read this class does, and only ever because the user asked to
  /// restore. Nothing here runs on a timer: that would be the first half of
  /// two-way sync, which is a different feature with a different cost. See
  /// `docs/backup-and-sync.md` section 6.3.
  Future<CloudFetch> latest() async {
    if (!isSupported) return const CloudFetch(CloudState.unsupported);

    try {
      final files = await ICloudStorage.gather(containerId: containerId);
      final match = files
          .where((file) => file.relativePath == fileName)
          .firstOrNull;
      if (match == null) return const CloudFetch(CloudState.missing);

      final destination = File(
        p.join((await getTemporaryDirectory()).path, 'cloud', 'restore.json'),
      );
      destination.parent.createSync(recursive: true);
      if (destination.existsSync()) destination.deleteSync();

      await _download(destination);

      // The wait can end without the file arriving, and an empty read would
      // reach the format check as "not a Subdock backup", which blames the
      // user's file for a network that timed out.
      if (!destination.existsSync() || destination.lengthSync() == 0) {
        return const CloudFetch(
          CloudState.failed,
          detail: 'the copy did not finish downloading',
        );
      }

      return CloudFetch(
        CloudState.saved,
        copy: CloudCopy(
          contents: await destination.readAsString(),
          changedAt: match.contentChangeDate,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == PlatformExceptionCode.iCloudConnectionOrPermission) {
        return const CloudFetch(CloudState.signedOut);
      }
      if (error.code == PlatformExceptionCode.fileNotFound) {
        return const CloudFetch(CloudState.missing);
      }
      return CloudFetch(CloudState.failed, detail: error.message);
    } on Exception catch (error) {
      return CloudFetch(CloudState.failed, detail: '$error');
    }
  }

  /// Waits for a download the plugin starts but does not wait for.
  ///
  /// `download` returns as soon as the request is filed, so the only signal
  /// that it finished is the progress stream closing. Bounded by
  /// [_fetchTimeout] and swallowing the timeout on purpose: a file already
  /// held locally can arrive without the stream ever reporting anything, and
  /// the caller checks the file itself rather than trusting this.
  Future<void> _download(File destination) async {
    final done = Completer<void>();

    await ICloudStorage.download(
      containerId: containerId,
      relativePath: fileName,
      destinationFilePath: destination.path,
      onProgress: (stream) => stream.listen(
        (_) {},
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
        cancelOnError: true,
      ),
    );

    try {
      await done.future.timeout(_fetchTimeout);
    } on TimeoutException {
      // Deliberately not an error here. See the doc comment.
    }
  }

  /// Staged in the temporary directory because the plugin uploads from a path.
  ///
  /// A fixed name, overwritten each time, so a phone that backs up every day
  /// for a year does not leave a year of files in a directory nobody looks at.
  Future<File> _stage(String contents) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, 'cloud'),
    );
    if (!directory.existsSync()) directory.createSync(recursive: true);

    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(contents);
    return file;
  }
}
