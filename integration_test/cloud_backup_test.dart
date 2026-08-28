import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/icloud_backup.dart';

/// The real plugin, called for real, on a device.
///
/// `backup_test.dart` puts a fake in place of [CloudBackup] and tests the
/// wiring above it, which is the right shape for everything that file covers
/// and leaves this class itself untested by anything. Nothing else in the repo
/// ever calls the plugin: a build where it is not registered at all, or where
/// its errors stopped mapping onto [CloudState], is green everywhere.
///
/// There is no iCloud container on a simulator, so every call here comes back
/// [CloudState.signedOut] and that is the whole assertion. It is worth more
/// than it looks. A plugin the build never registered answers with a
/// `MissingPluginException`, which is an [Exception] like any other and lands
/// in the catch-all as [CloudState.failed] with a message nobody reads. On
/// screen the two are a world apart: `signedOut` prints the one sentence the
/// user can act on, and `failed` prints an apology for a bug.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final cloud = ICloudBackup();

  /// Signed in, and this machine happens to have a container. Then the call
  /// really worked, which is also a pass; the point is that neither answer is
  /// [CloudState.failed].
  const reachable = {CloudState.saved, CloudState.signedOut};

  testWidgets('a write reaches the plugin and comes back mapped', (
    tester,
  ) async {
    final result = await cloud.save('{"version":1,"items":[]}');

    expect(
      reachable,
      contains(result.state),
      reason: 'failed here means the plugin never answered: ${result.detail}',
    );
  });

  testWidgets('a read reaches the plugin and comes back mapped', (
    tester,
  ) async {
    final fetch = await cloud.latest();

    // `missing` joins the set for a signed-in machine with an empty
    // container, which is the state a fresh install is in.
    expect(
      {...reachable, CloudState.missing},
      contains(fetch.state),
      reason: 'failed here means the plugin never answered: ${fetch.detail}',
    );
  });
}
