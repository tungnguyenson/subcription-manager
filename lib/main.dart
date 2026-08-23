import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/bundled_data.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/connection.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/item_actions.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/platform/notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The design commits to one light look, so the status bar is pinned rather
  // than left to follow a system setting the app does not otherwise honour.
  // `dark` here means dark *content* on a light ground, which is what a page
  // with a #ECECEB background needs.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  // Portrait only. Every screen is a single column of rows; landscape would
  // stretch a 15px-padded card across a phone's long edge to no benefit.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final database = await openDatabase();
  final repository = ItemRepository(database);
  final settings = SettingsStore(database);

  final catalog = ServiceCatalog(
    BundledData.parseCatalog(
      await rootBundle.loadString('assets/services.json'),
    ).entries,
  );

  final scheduler = NotificationScheduler();
  // Categories must be registered before any alert is scheduled: iOS binds a
  // notification's buttons at registration time, not at delivery time.
  //
  // The handler is installed here rather than in a widget because a
  // notification button is answered with the app in whatever state iOS
  // happens to give us — often with no route on screen at all. It writes
  // through the repository, and the UI redraws from the stream it is already
  // listening to.
  await scheduler.initialise(
    onTap: (payload, actionId) =>
        _handleNotificationAction(repository, payload, actionId),
  );

  runApp(
    SubdockApp(
      repository: repository,
      settings: settings,
      scheduler: scheduler,
      catalog: catalog,
    ),
  );
}

Future<void> _handleNotificationAction(
  ItemRepository repository,
  String? itemId,
  String? actionId,
) async {
  if (itemId == null || actionId == null) return;

  final item = await repository.findById(itemId);
  if (item == null) return;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  switch (actionId) {
    case NotificationAction.done:
      await repository.recordHandled(ItemActions.handledEvent(item, now));
      await repository.upsert(ItemActions.advanced(item), now);
    case NotificationAction.snoozeOneDay:
      await repository.upsert(
        ItemActions.snoozed(item, LocalDate.today().plusDays(1)),
        now,
      );
    // `openItem` and a plain tap both just bring the app forward, which iOS
    // has already done by the time this runs.
  }
}
