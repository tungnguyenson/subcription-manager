import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/item_actions.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/add_item_screen.dart';
import 'package:subdock/ui/screens/history_screen.dart';
import 'package:subdock/ui/screens/item_detail_screen.dart';
import 'package:subdock/ui/screens/money_screen.dart';
import 'package:subdock/ui/screens/onboarding_screen.dart';
import 'package:subdock/ui/screens/reminder_rules_screen.dart';
import 'package:subdock/ui/screens/reminders_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/item_row.dart';

class SubdockApp extends StatelessWidget {
  final ItemRepository repository;
  final SettingsStore settings;
  final NotificationScheduler scheduler;
  final ServiceCatalog catalog;

  const SubdockApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.scheduler,
    required this.catalog,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subdock',
      debugShowCheckedModeBanner: false,
      theme: buildSubdockTheme(),
      home: HomePage(
        repository: repository,
        settings: settings,
        scheduler: scheduler,
        catalog: catalog,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ItemRepository repository;
  final SettingsStore settings;
  final NotificationScheduler scheduler;
  final ServiceCatalog catalog;

  const HomePage({
    super.key,
    required this.repository,
    required this.settings,
    required this.scheduler,
    required this.catalog,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ShellTab _tab = ShellTab.upcoming;

  List<TrackedItem> _items = const [];
  List<HandledEvent> _history = const [];
  AppSettings _settings = const AppSettings();
  NotificationPlan _plan = const NotificationPlan(alerts: [], dropped: []);

  StreamSubscription<List<TrackedItem>>? _itemSubscription;
  StreamSubscription<List<HandledEvent>>? _historySubscription;
  StreamSubscription<AppSettings>? _settingsSubscription;

  bool _loaded = false;
  bool _onboardingDismissed = false;
  bool _notificationsGranted = false;

  /// The identifiers currently on the device. Re-scheduling means cancelling
  /// and re-adding all of them, which is cheap but not free, so it only runs
  /// when the plan actually differs.
  String _appliedSignature = '';

  @override
  void initState() {
    super.initState();

    // Subscribed here rather than through a StreamBuilder because re-planning
    // notifications is a side effect, and a side effect inside build() runs on
    // every rebuild, including ones caused by switching tabs.
    _itemSubscription = widget.repository.observeAll().listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _loaded = true;
        _plan = NotificationPlanner.plan(items, LocalDate.today());
      });
      unawaited(_applyPlan());
    });

    _historySubscription = widget.repository
        .observeHistorySince(LocalDate.today().minusDays(365))
        .listen((events) {
          if (!mounted) return;
          setState(() => _history = events);
        });

    _settingsSubscription = widget.settings.observe().listen((settings) {
      if (!mounted) return;
      setState(() => _settings = settings);
    });

    unawaited(_refreshPermission());
  }

  @override
  void dispose() {
    _itemSubscription?.cancel();
    _historySubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    final granted = await widget.scheduler.hasPermission();
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _applyPlan() async {
    final signature = _plan.alerts.map((a) => a.identifier).join('|');
    if (signature == _appliedSignature) return;

    // Do not schedule against a permission the user has not granted: the
    // plugin would accept the calls and silently drop every one of them.
    if (!await widget.scheduler.hasPermission()) return;

    await widget.scheduler.apply(_plan);
    _appliedSignature = signature;
  }

  /// Shown once, on a database that has never held anything.
  ///
  /// Keyed off "no items and not dismissed" rather than a stored flag: a user
  /// who deletes everything is back to knowing nothing about the app, and a
  /// flag would deny them the explanation.
  bool get _showOnboarding =>
      _loaded && _items.isEmpty && !_onboardingDismissed;

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return Scaffold(
        backgroundColor: SubdockColors.canvas,
        body: SafeArea(
          child: OnboardingScreen(
            notificationsGranted: _notificationsGranted,
            onAllowNotifications: _requestNotifications,
            onStart: () => setState(() => _onboardingDismissed = true),
          ),
        ),
      );
    }

    return AppShell(
      current: _tab,
      onSelect: (tab) => setState(() => _tab = tab),
      onAdd: _openAdd,
      child: _screenFor(LocalDate.today()),
    );
  }

  Widget _screenFor(LocalDate today) {
    switch (_tab) {
      case ShellTab.upcoming:
        return UpcomingScreen(
          view: UpcomingPresenter.build(_items, today),
          banner: _notificationsGranted
              ? null
              : AlertBanner(
                  title: 'Notifications are off',
                  body: 'The list works, but nothing will remind you.',
                  actionLabel: 'On',
                  onAction: _requestNotifications,
                ),
          onAdd: _openAdd,
          onOpen: _openEntry,
        );

      case ShellTab.money:
        return MoneyScreen(
          thisMonth: _monthTotal(today),
          items: _monthItems(today),
        );

      case ShellTab.settings:
        return SettingsScreen(
          // Surfaced, never buried: iOS drops the furthest-out pending
          // notifications silently, and the user has no other way to find out
          // that a reminder they are relying on was never scheduled.
          droppedReminders: _plan.dropped
              .map((alert) => alert.itemName)
              .toSet()
              .toList(),
          onOpenReminders: _openReminderRules,
          onOpenHistory: _openHistory,
        );
    }
  }

  Future<void> _requestNotifications() async {
    await widget.scheduler.requestPermission();
    await _refreshPermission();
    // The plan was computed while permission was still missing, so nothing was
    // scheduled. Force a re-apply rather than waiting for the next data change.
    _appliedSignature = '';
    await _applyPlan();
  }

  void _openEntry(UpcomingEntry entry) {
    final item = _items.where((i) => i.id == entry.id).firstOrNull;
    if (item != null) _openItem(item);
  }

  void _openItem(TrackedItem item) {
    final held = _plan.alerts.where((a) => a.itemId == item.id).length;
    final next = _plan.alerts
        .where((a) => a.itemId == item.id)
        .map((a) => '${MoneyFormat.shortDate(a.date)} at ${a.time}')
        .firstOrNull;

    _push(
      ItemDetailScreen(
        item: item,
        today: LocalDate.today(),
        history: _history.where((e) => e.itemId == item.id).toList(),
        scheduledCount: held,
        nextReminder: next,
        onEdit: () => _openEdit(item),
        onMarkPaid: () => _markPaid(item),
        onSnooze: () => _snooze(item, 3),
        onDelete: () => _delete(item),
        onStop: () => _stop(item),
        onEditReminders: () => _push(
          RemindersScreen(
            item: item,
            today: LocalDate.today(),
            heldSlots: held,
            droppedElsewhere: _plan.dropped
                .where((a) => a.itemId != item.id)
                .length,
            onToggleLead: (lead, on) => _toggleLead(item, lead, on),
          ),
        ),
      ),
    );
  }

  void _openAdd() {
    _push(
      AddItemScreen(
        catalog: widget.catalog,
        today: LocalDate.today(),
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: _saveDraft,
        onPickDate: _pickDate,
      ),
    );
  }

  /// Opens the same form on an item that already exists.
  void _openEdit(TrackedItem item) {
    _push(
      AddItemScreen(
        catalog: widget.catalog,
        today: LocalDate.today(),
        initial: DraftItem.of(item),
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: (draft) => _saveEdit(item, draft),
        onPickDate: _pickDate,
      ),
    );
  }

  /// Writes the edit and puts the user back on the item's own screen.
  ///
  /// Two routes come off the stack, not one. The detail screen underneath the
  /// editor is a snapshot of the item as it was before the edit, so leaving it
  /// there would show the old price under a message saying the new one was
  /// saved. It is replaced with the same screen built from the new item.
  Future<void> _saveEdit(TrackedItem original, DraftItem draft) async {
    final updated = draft.applyTo(original);
    await widget.repository.upsert(
      updated,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pop();
    if (navigator.canPop()) navigator.pop();
    _openItem(updated);
    _confirm('Saved "${updated.name}".');
  }

  void _openHistory() => _push(
    HistoryScreen(
      currentYear: LocalDate.today().year,
      done: HistoryFromEvents.build(_history, {
        for (final item in _items) item.id: item,
      }),
    ),
  );

  void _openReminderRules() => _push(
    ReminderRulesScreen(
      settings: _settings,
      pushGranted: _notificationsGranted,
      onEnablePush: _requestNotifications,
      onToggleLead: (lead, on) =>
          widget.settings.save(_settings.withLead(lead, on)),
      onPickTime: _pickRemindTime,
    ),
  );

  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: SubdockColors.canvas,
          body: SafeArea(bottom: false, child: screen),
        ),
      ),
    );
  }

  /// The calendar, opened on [from] when the form already holds a date.
  ///
  /// The range reaches into the past. A bill that is already overdue is a
  /// real thing to add, and correcting a date the user typed wrong is the
  /// whole point of the editor; a picker that only goes forwards can do
  /// neither.
  Future<LocalDate?> _pickDate([LocalDate? from]) async {
    final today = LocalDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ?? today.plusDays(30)).toDateTimeMidnight(),
      firstDate: today.plusYears(-5).toDateTimeMidnight(),
      lastDate: today.plusYears(20).toDateTimeMidnight(),
    );
    return picked == null ? null : LocalDate.fromDateTime(picked);
  }

  Future<void> _pickRemindTime() async {
    final current = _settings.remindAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await widget.settings.save(
      _settings.withRemindAt(LocalTime(picked.hour, picked.minute)),
    );
  }

  Future<void> _saveDraft(DraftItem draft) async {
    final matched = draft.matched;

    final item = TrackedItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
      category: draft.category,
      iconName: draft.iconName,
      expiresOn: draft.expiresOn,
      anchorDate: draft.expiresOn,
      cycle: draft.cycle,
      repeatCount: draft.repeatCount,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      actionUrl: matched?.cancelUrl,
      note: matched?.noteVi,
      leadDays: draft.leadDays,
      remindAt: _settings.remindAt,
      // The user typed this date from memory unless they say otherwise.
      dateSource: DateSource.userEstimated,
    );

    await widget.repository.upsert(
      item,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;

    Navigator.of(context).maybePop();
    // An item dated a year out lands in a collapsed fold, so saving it looks
    // exactly like saving nothing. Say where it went.
    _confirm(_savedMessage(item));
  }

  String _savedMessage(TrackedItem item) {
    final days = LocalDate.today().daysUntil(item.actBy);
    if (days > UpcomingPresenter.monthHorizonDays) {
      return 'Saved "${item.name}" — it is under Later.';
    }
    if (days > UpcomingPresenter.weekHorizonDays) {
      return 'Saved "${item.name}" — it is under Next 30 days.';
    }
    return 'Saved "${item.name}".';
  }

  void _confirm(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: SubdockText.rowValue.copyWith(color: SubdockColors.card),
        ),
        backgroundColor: SubdockColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SubdockRadius.card),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleLead(TrackedItem item, int lead, bool on) async {
    final leads = {...item.leadDays};
    if (on) {
      leads.add(lead);
    } else {
      leads.remove(lead);
    }
    final sorted = leads.toList()..sort((a, b) => b.compareTo(a));

    await widget.repository.upsert(
      item.copyWith(leadDays: sorted),
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Records the payment and moves the item on to its next occurrence.
  ///
  /// The advance is the half that used to be missing. Marking a monthly bill
  /// paid and leaving its due date in the past turns a handled item into an
  /// overdue one on the very next launch.
  Future<void> _markPaid(TrackedItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await widget.repository.recordHandled(ItemActions.handledEvent(item, now));
    await widget.repository.upsert(ItemActions.advanced(item), now);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// Postpones this item's nudge by [days], from the detail screen's
  /// "Remind me again in 3 days" and from the notification's "Remind
  /// tomorrow".
  ///
  /// Replaces any snooze already set rather than queueing a second one: asking
  /// twice means "not now" twice, not "twice as many reminders".
  Future<void> _snooze(TrackedItem item, int days) async {
    final until = LocalDate.today().plusDays(days);
    await widget.repository.upsert(
      ItemActions.snoozed(item, until),
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;
    Navigator.of(context).maybePop();
    _confirm('Reminding you again on ${MoneyFormat.shortDate(until)}.');
  }

  /// Ends the series after the payment that is currently due.
  Future<void> _stop(TrackedItem item) async {
    final stopped = ItemActions.stopped(item);

    await widget.repository.upsert(
      stopped,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete(TrackedItem item) async {
    await widget.repository.delete(item.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// This month's committed spend.
  ///
  /// Documents are excluded by [TrackedItem.countsTowardSpend]: a passport
  /// costs money to renew but is not a subscription, and folding it into a
  /// monthly figure would make the total answer a question nobody asked.
  List<TrackedItem> _monthly(LocalDate today) => [
    for (final item in _items)
      if (item.countsTowardSpend &&
          item.state == ItemState.active &&
          item.expiresOn.month == today.month &&
          item.expiresOn.year == today.year)
        item,
  ];

  MixedTotal _monthTotal(LocalDate today) => Fx.total(
    [for (final item in _monthly(today)) item.money!],
    rate: Fx.bundledUsdVnd,
    today: today,
  );

  List<ItemSpend> _monthItems(LocalDate today) {
    final rows = [
      for (final item in _monthly(today))
        ItemSpend(
          name: item.name,
          total: Fx.total(
            [item.money!],
            rate: Fx.bundledUsdVnd,
            today: today,
          ).approximateBase!,
          // The exact foreign figure is kept beside the converted one, because
          // it is the part that is actually true.
          foreign: item.currency == Fx.bundledUsdVnd.to ? null : item.money,
        ),
    ];

    rows.sort((a, b) => b.total.minor.compareTo(a.total.minor));
    return rows;
  }
}
