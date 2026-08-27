import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:subdock/i18n.dart';

/// Hands a backup to the operating system, and takes one back.
///
/// The app never picks where the file lives. There is no folder inside it to
/// browse and no cloud account behind it, so the only honest place for a backup
/// is wherever the user already keeps things they mean to keep -- Files,
/// iCloud, Drive, a chat with themselves. Both directions therefore go through
/// the system's own sheets rather than anything drawn here.
///
/// A class rather than top-level functions so a widget test can put a fake in
/// its place, the same way [NotificationScheduler] is handled.
class BackupFiles {
  /// Where the file about to be shared is staged.
  ///
  /// Its own directory inside the temporary one, emptied before each export, so
  /// a year of backups does not quietly accumulate in a folder the user cannot
  /// see. The share sheet copies what it needs before this is next cleared.
  static const String _stagingDir = 'backup';

  /// Writes [contents] to a file named [fileName] and opens the share sheet.
  ///
  /// [origin] anchors the popover on iPad, where a share sheet with nothing to
  /// point at is a crash rather than a centred dialog. Null everywhere else.
  ///
  /// [mimeType] is what the receiving app is told it is getting. It decides
  /// which apps the sheet even offers: a spreadsheet handed over as
  /// `application/json` is a file Numbers and Sheets will not appear for.
  ///
  /// Returns false when the user dismissed the sheet without choosing anything,
  /// so the caller can stay quiet rather than claiming a backup was saved.
  Future<bool> save(
    String contents,
    String fileName, {
    String mimeType = 'application/json',
    Rect? origin,
  }) async {
    final staged = await _stage(contents, fileName);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(staged.path, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );

    // `unavailable` is the platforms that cannot report an outcome. Treated as
    // success, because the sheet did open and the app has no way to know
    // otherwise; calling it a failure would tell a user who just saved a file
    // that they did not.
    return result.status != ShareResultStatus.dismissed;
  }

  /// Opens the system file picker and reads what comes back.
  ///
  /// Returns null when the user cancelled. Read through [PlatformFile.readAsBytes]
  /// rather than from a path: a file chosen out of iCloud Drive or Google Drive
  /// arrives as a content URI with no local path at all, and reading by path
  /// would fail for exactly the person who kept their backup somewhere safe.
  Future<String?> pick() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: S.t.chooseABackup,
      // Filtered but not enforced: the JSON is what gets validated, and some
      // providers hand back a file whose name lost its extension in transit.
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;

    return utf8.decode(await picked.readAsBytes(), allowMalformed: true);
  }

  Future<File> _stage(String contents, String fileName) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, _stagingDir),
    );
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);

    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(contents);
    return file;
  }
}
