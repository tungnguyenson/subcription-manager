import 'package:integration_test/integration_test_driver.dart';

/// The driver half of `flutter drive`, and the only way to run anything in
/// `integration_test/` against a wirelessly connected iPhone.
///
/// `flutter test` hard-codes `disablePortPublication: true`
/// (`flutter_tools/lib/src/commands/test.dart`), and a wireless iOS device
/// needs the port published because the connection goes over mDNS. So the run
/// dies before the first test loads, with a message telling you to pass
/// `--publish-port` -- an option `flutter test` does not have. `flutter drive`
/// does have it, and turns it on by itself when the target is wireless.
///
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/notification_ceiling_test.dart \
///   -d "TNS iPhone"
/// ```
///
/// Over a cable, plain `flutter test integration_test/<file> -d <id>` still
/// works and is faster. This file is for when the cable is not an option.
Future<void> main() => integrationDriver();
