import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/item_actions.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/domain/backup.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/filter_presenter.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/manage_presenter.dart';
import 'package:subdock/ui/reminder_timeline.dart';
import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/add_item_screen.dart';
import 'package:subdock/ui/screens/history_screen.dart';
import 'package:subdock/ui/screens/item_detail_screen.dart';
import 'package:subdock/ui/money_presenter.dart';
import 'package:subdock/ui/savings_presenter.dart';
import 'package:subdock/ui/services_presenter.dart';
import 'package:subdock/ui/screens/money_screen.dart';
import 'package:subdock/ui/screens/savings_screen.dart';
import 'package:subdock/ui/screens/services_screen.dart';
import 'package:subdock/ui/screens/sources_screen.dart';
import 'package:subdock/ui/screens/onboarding_screen.dart';
import 'package:subdock/ui/screens/reminder_rules_screen.dart';
import 'package:subdock/ui/screens/reminders_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/delete_ask.dart';
import 'package:subdock/ui/widgets/restore_ask.dart';
import 'package:subdock/ui/widgets/filter_sheet.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/notification_ask.dart';
import 'package:url_launcher/url_launcher.dart';

class SubdockApp extends StatelessWidget {
  final ItemRepository repository;
  final SettingsStore settings;
  final FilterStore filters;
  final NotificationScheduler scheduler;
  final ServiceCatalog catalog;
  final BackupStore backups;
  final BackupFiles files;
  final CloudBackup cloud;

  const SubdockApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.filters,
    required this.scheduler,
    required this.catalog,
    required this.backups,
    required this.files,
    required this.cloud,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subdock',
      debugShowCheckedModeBanner: false,
      theme: buildSubdockTheme(),
      home: HomePage(
        backups: backups,
        files: files,
        cloud: cloud,
        repository: repository,
        settings: settings,
        filters: filters,
        scheduler: scheduler,
        catalog: catalog,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ItemRepository repository;
  final SettingsStore settings;
  final FilterStore filters;
  final NotificationScheduler scheduler;
  final ServiceCatalog catalog;
  final BackupStore backups;
  final BackupFiles files;
  final CloudBackup cloud;

  const HomePage({
    super.key,
    required this.repository,
    required this.settings,
    required this.filters,
    required this.scheduler,
    required this.catalog,
    required this.backups,
    required this.files,
    required this.cloud,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  ShellTab _tab = ShellTab.upcoming;

  List<TrackedItem> _items = const [];

  /// The user's shelves, read from storage like everything else.
  ///
  /// Seeded with the shipped list so the first frame has labels rather than
  /// blanks; the stream replaces it as soon as the read comes back, and every
  /// screen that needs a shelf is handed this rather than reaching for the
  /// defaults itself.
  CategoryBook _categories = CategoryBook.shipped;

  List<HandledEvent> _history = const [];
  List<PaymentSource> _sources = const [];
  AppSettings _settings = const AppSettings();
  NotificationPlan _plan = const NotificationPlan(alerts: [], dropped: []);

  /// Which span the Spending screen is on. Held here rather than in the screen
  /// so it survives the rebuild every data change causes.
  MoneySpan _span = MoneySpan.month;

  /// Which month of the chart the Spending screen is showing, 1 to 12. Null
  /// until the user taps a column, which is how the screen keeps following the
  /// calendar for anyone who never touches it: a session left open past
  /// midnight on the 31st opens on the new month rather than on the old one.
  int? _monthShowing;

  /// What Upcoming is narrowed to. Held here for the same reason as [_span],
  /// and written to storage as well, so it also survives the app being killed.
  UpcomingFilter _filter = UpcomingFilter.none;

  StreamSubscription<List<PaymentSource>>? _sourceSubscription;
  StreamSubscription<List<TrackedItem>>? _itemSubscription;
  StreamSubscription<List<Category>>? _categorySubscription;
  StreamSubscription<List<HandledEvent>>? _historySubscription;
  StreamSubscription<AppSettings>? _settingsSubscription;
  StreamSubscription<LocalDate?>? _lastBackupSubscription;

  bool _loaded = false;
  bool _onboardingDismissed = false;
  bool _notificationsGranted = false;

  /// How the last write to the user's own cloud went.
  CloudResult _cloud = CloudResult.idle;

  /// Holds the cloud write back until the edits stop.
  ///
  /// Every keystroke in the note field is a database write and therefore a
  /// stream event. Uploading on each one would spend the user's battery and
  /// their data on thirty copies of a sentence being typed.
  Timer? _cloudDebounce;

  /// When a backup last actually left the device, or null if never.
  LocalDate? _lastBackupOn;

  /// Null until the first read, and null for good on any platform that does
  /// not gate exact alarms behind their own permission.
  bool? _exactTiming;

  /// The identifiers currently on the device. Re-scheduling means cancelling
  /// and re-adding all of them, which is cheap but not free, so it only runs
  /// when the plan actually differs.
  String _appliedSignature = '';

  /// The item whose provider page the user was just sent to, if they have not
  /// come back yet.
  ///
  /// This is the app's one chance to turn a guessed date into a confirmed one:
  /// the user has just read the real renewal date off the provider's own page,
  /// and thirty seconds later they will not remember it. Everything else the
  /// app knows about dates is what someone typed from memory.
  String? _openedProviderPageFor;

  /// How many items the user has saved this run, and where they last declined
  /// the notification prompt.
  ///
  /// The prompt fires on the first save and then not again until two more items
  /// have gone in. iOS asks the system question exactly once — a decline there
  /// is permanent — so the app's own sheet has to be shown at the moment the
  /// answer is most likely to be yes, and never so often that it trains the
  /// user to dismiss it.
  int _saves = 0;
  int? _declinedAtSave;

  /// Items already asked about after such a trip. Held for this run only, and
  /// deliberately not persisted: the rule is "do not ask twice in a row", not
  /// "never ask again", and a stored flag would silently close the door on a
  /// user who dismissed the prompt with their thumb on the way past.
  final Set<String> _askedRenewal = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Subscribed here rather than through a StreamBuilder because re-planning
    // notifications is a side effect, and a side effect inside build() runs on
    // every rebuild, including ones caused by switching tabs.
    // Ahead of the items, because the plan an item change triggers reads a
    // shelf's nag policy. A first frame planned against the shipped defaults
    // would re-plan a moment later anyway; this way it usually does not have
    // to.
    _categorySubscription = widget.repository.observeCategories().listen((
      categories,
    ) {
      if (!mounted) return;
      setState(() => _categories = CategoryBook(categories));
      _replan();
      _scheduleCloudBackup();
    });

    _itemSubscription = widget.repository.observeAll().listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _loaded = true;
      });
      _replan();
      _scheduleCloudBackup();
    });

    _historySubscription = widget.repository
        .observeHistorySince(LocalDate.today().minusDays(365))
        .listen((events) {
          if (!mounted) return;
          setState(() => _history = events);
        });

    _sourceSubscription = widget.repository.observeSources().listen((sources) {
      if (!mounted) return;
      setState(() => _sources = sources);
      // Deleting a source in Settings must not leave Upcoming filtered by an
      // id nothing can match. Done here rather than at the read, because the
      // read can land before the sources do -- pruning against a list that has
      // not arrived yet would throw away a filter that was perfectly valid.
      _setFilter(_filter.prunedTo({for (final source in sources) source.id}));
    });

    _settingsSubscription = widget.settings.observe().listen((settings) {
      if (!mounted) return;
      setState(() => _settings = settings);
    });

    _lastBackupSubscription = widget.backups.observeLastSaved().listen((on) {
      if (!mounted) return;
      setState(() => _lastBackupOn = on);
    });

    unawaited(_refreshPermission());
    unawaited(_restoreFilter());
  }

  /// Puts back the filter the last session left on Upcoming.
  ///
  /// Skipped if the user has already touched the sheet -- the read is one
  /// round trip to sqlite and they cannot realistically win the race, but
  /// losing it would mean the app overwriting a tap they just made.
  Future<void> _restoreFilter() async {
    final stored = await widget.filters.read();
    if (!mounted || stored.isEmpty || _filter.isNotEmpty) return;
    setState(() => _filter = stored);
  }

  /// The one way the filter changes, so it can never be written to the screen
  /// without also being written down.
  void _setFilter(UpcomingFilter next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    unawaited(widget.filters.save(next));
  }

  /// The chips the sheet offers, rebuilt from the current data every time it
  /// opens. A shelf the user emptied yesterday should not still have a chip.
  FilterOptions get _filterOptions =>
      FilterPresenter.options(_items, _categories, sources: _sources);

  void _openFilter() {
    unawaited(
      FilterSheet.show(
        context,
        filter: _filter,
        options: _filterOptions,
        // Counted over items rather than read off the view, so the number on
        // the button is the same one the summary line will show.
        countFor: (filter) => filter.apply(_items, LocalDate.today()).length,
        onChanged: _setFilter,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _itemSubscription?.cancel();
    _categorySubscription?.cancel();
    _sourceSubscription?.cancel();
    _historySubscription?.cancel();
    _settingsSubscription?.cancel();
    _lastBackupSubscription?.cancel();
    _cloudDebounce?.cancel();
    super.dispose();
  }

  /// Catches the user coming back from a provider's billing page.
  ///
  /// [launchUrl] returns the moment iOS accepts the hand-off, not when the
  /// user returns, so the trip has to be noticed here instead.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app is when the user has stopped editing, and it is the last
    // moment the process is reliably alive. A pending cloud write goes now
    // rather than waiting out a timer that may never fire.
    if (state == AppLifecycleState.paused && _cloudDebounce?.isActive == true) {
      unawaited(_runCloudBackup());
    }
    if (state != AppLifecycleState.resumed) return;

    // Both of these are stale by the time the app comes back, and neither
    // arrives through a stream. The clock has moved, and the two Android
    // permissions are granted on a system settings screen the app cannot
    // observe -- `requestExactAlarmsPermission` only opens it, and the answer
    // exists nowhere until someone asks again.
    _replan();
    unawaited(_refreshPermission());

    final itemId = _openedProviderPageFor;
    _openedProviderPageFor = null;
    if (itemId == null) return;

    final item = _items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    if (!_askedRenewal.add(item.id)) return;

    _offerRenewalDate(item);
  }

  Future<void> _refreshPermission() async {
    final granted = await widget.scheduler.hasPermission();
    // Read even when permission is off, so the reminders screen has the answer
    // ready the moment the user grants it.
    final exact = await widget.scheduler.hasExactTiming();
    if (mounted) {
      setState(() {
        _notificationsGranted = granted;
        _exactTiming = exact;
      });
    }
  }

  /// Queues a cloud write for once the edits have stopped.
  ///
  /// Fired from the streams carrying the user's own rows, and deliberately not
  /// from the settings stream: [BackupStore.markSaved] writes a settings row,
  /// so listening there would have every upload schedule the next one.
  void _scheduleCloudBackup() {
    if (!widget.cloud.isSupported) return;
    _cloudDebounce?.cancel();
    _cloudDebounce = Timer(_cloudDelay, () => unawaited(_runCloudBackup()));
  }

  /// Long enough to swallow a form being filled in, short enough that closing
  /// the app a minute later still leaves a copy behind. Backgrounding flushes
  /// it early, which is the case that actually matters: leaving the app is
  /// exactly when the user stops making changes.
  static const Duration _cloudDelay = Duration(seconds: 12);

  Future<void> _runCloudBackup() async {
    _cloudDebounce?.cancel();
    _cloudDebounce = null;
    if (!widget.cloud.isSupported || !_loaded) return;

    final at = DateTime.now();
    final backup = await widget.backups.read(clock: at);
    final result = await widget.cloud.save(BackupCodec.encode(backup));

    // Only a write that landed counts as a backup. Recording one for a failed
    // upload would put a date under `Last backup` and take the warning off the
    // screen, for a file that is not there.
    if (result.state == CloudState.saved) {
      await widget.backups.markSaved(LocalDate.fromDateTime(at));
    }
    if (mounted) setState(() => _cloud = result);
  }

  /// Recomputes the plan against the clock and puts it on the device.
  ///
  /// The clock is an input, not just the data. An alert set for 08:30 today is
  /// the next one at 08:29 and is history at 08:31, and no database row
  /// changes at that minute -- so this has to run on resume as well as on
  /// every data change, or the app goes on offering a reminder that has
  /// already been and gone. See [NotificationPlanner.plan].
  void _replan() {
    if (!mounted) return;
    setState(() {
      _plan = NotificationPlanner.plan(
        _items,
        _categories,
        LocalDateTime.now(),
      );
    });
    unawaited(_applyPlan());
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
      // The gradient, not the flat mid-tone. Onboarding is the first thing the
      // user sees and it is where the look has to land; `canvas` here painted
      // the whole screen the colour that is only meant to stand in where a
      // gradient cannot go.
      return GlassBackground(
        child: Scaffold(
          backgroundColor: const Color(0x00000000),
          body: SafeArea(
            child: OnboardingScreen(
              notificationsGranted: _notificationsGranted,
              onAllowNotifications: _requestNotifications,
              onStart: () => setState(() => _onboardingDismissed = true),
              // Tries iCloud first and falls back to the file picker. Unlike
              // Settings, this screen gets one button rather than two: there
              // is no list here to endanger, so guessing the likely source
              // costs nothing and saves the one person in a hurry a decision.
              onRestore: () => unawaited(_restoreOnArrival()),
            ),
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
        final upcoming = UpcomingPresenter.build(
          _items,
          today,
          sources: _sourcesById,
          filter: _filter,
        );
        return UpcomingScreen(
          view: upcoming,
          filterSummary: _filter.isEmpty
              ? null
              : FilterPresenter.summary(
                  _filter,
                  _filterOptions,
                  shown: upcoming.shown,
                  total: upcoming.total,
                ),
          onOpenFilter: _openFilter,
          onClearFilter: () => _setFilter(UpcomingFilter.none),
          banner: _notificationsGranted
              ? null
              : AlertBanner(
                  title: 'Notifications are off',
                  body: 'Nothing will remind you.',
                  actionLabel: 'On',
                  onAction: _requestNotifications,
                ),
          onAdd: _openAdd,
          onOpen: _openEntry,
          onOpenServices: _openServices,
        );

      case ShellTab.money:
        final savings = _savings(today);
        return MoneyScreen(
          view: MoneyPresenter.build(
            items: _items,
            categories: _categories,
            today: today,
            span: _span,
            month: _monthShowing,
          ),
          onSpan: (span) => setState(() => _span = span),
          onMonth: (month) => setState(() => _monthShowing = month),
          // The teaser only appears when there is something behind it. A card
          // saying "cut 0 ₫ a year" is worse than no card: it teaches the user
          // that the savings screen has nothing on it.
          savings: savings.hasYearly
              ? SavingsTeaser(
                  headline: 'Cut ${savings.total} a year',
                  line:
                      '${savings.yearly.length} '
                      '${savings.yearly.length == 1 ? "plan" : "plans"} '
                      'cost less yearly · cancelling saves more',
                )
              : null,
          onOpenSavings: () => setState(() => _tab = ShellTab.savings),
          onOpenHistory: _openHistory,
        );

      case ShellTab.savings:
        return SavingsScreen(
          view: _savings(today),
          monthlyCount: SavingsPresenter.monthlyCount(
            _items,
            _categories,
            today,
          ),
          onChoose: _setYearlyChoice,
          onUnskip: () => unawaited(widget.repository.clearSkippedYearly()),
          onOpenItem: _openItemById,
          onOpenCancel: _openCancelPage,
          onRemove: _deleteById,
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
          servicesLine: _servicesLine,
          sourcesLine: _sources.isEmpty ? 'None' : '${_sources.length}',
          backup: BackupPresenter.build(
            items: _items,
            lastSavedOn: _lastBackupOn,
            device: _deviceBackup,
            cloud: _cloud,
          ),
          onOpenServices: _openServices,
          onOpenSources: _openSources,
          onOpenReminders: _openReminderRules,
          onOpenHistory: _openHistory,
          onExport: () => unawaited(_exportBackup()),
          onImport: () => unawaited(_importBackup()),
          onImportFromCloud: () => unawaited(_importFromCloud()),
        );
    }
  }

  Map<String, PaymentSource> get _sourcesById => {
    for (final source in _sources) source.id: source,
  };

  /// The last source the user chose, for the add form's default.
  ///
  /// Read off the items rather than stored as a preference: whatever most of
  /// their subscriptions already pay from is a better guess than the one they
  /// happened to pick last, and it needs no extra state to be right.
  String? get _lastUsedSourceId {
    final counts = <String, int>{};
    for (final item in _items) {
      final id = item.paymentSourceId;
      if (id != null) counts.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String get _servicesLine {
    final live = _items.where((i) => i.state != ItemState.archived).length;
    final off = _items.where((i) => i.paused).length;
    return off == 0 ? '$live' : '$live · $off off';
  }

  SavingsView _savings(LocalDate today) => SavingsPresenter.build(
    items: _items,
    catalog: widget.catalog,
    categories: _categories,
    today: today,
    defaultLeadDays: _settings.defaultLeadDays,
  );

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
    final category = _categories[item.categoryId];
    // Built from the plan, so it shows what is actually pending rather than
    // what the ladder would imply. A snooze, a nag and a dropped alert are all
    // invisible to `item.leadDays` and all visible here.
    final timeline = ReminderTimelinePresenter.of(
      item: item,
      category: category,
      alerts: _plan.alerts,
      dropped: _plan.dropped,
      today: LocalDate.today(),
    );

    _push(
      ItemDetailScreen(
        item: item,
        category: category,
        today: LocalDate.today(),
        history: _history.where((e) => e.itemId == item.id).toList(),
        scheduledCount: held,
        timeline: timeline,
        onEdit: () => _openEdit(item),
        onMarkPaid: () => _markPaid(item),
        onSnooze: () => _snooze(item, 3),
        onDelete: () => _delete(item),
        onStop: () => _stop(item),
        // Matched by name at display time, not stored on the item. The
        // catalogue grows between releases, so an item added before its
        // service had a price picks one up on the next update.
        catalogEntry: widget.catalog.matchByName(item.name),
        source: _sourcesById[item.paymentSourceId],
        onOpenManage: (action) => _openManage(item, action),
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
    _pushForm(
      AddItemScreen(
        catalog: widget.catalog,
        categories: _categories,
        today: LocalDate.today(),
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: _saveDraft,
        onPickDate: _pickDate,
        sources: _sources,
        onCreateSource: _createSource,
        defaultSourceId: _lastUsedSourceId,
      ),
    );
  }

  /// Opens the same form on an item that already exists.
  void _openEdit(TrackedItem item) {
    _pushForm(
      AddItemScreen(
        catalog: widget.catalog,
        categories: _categories,
        today: LocalDate.today(),
        initial: DraftItem.of(item, _categories),
        onCancel: () => Navigator.of(context).maybePop(),
        onSave: (draft) => _saveEdit(item, draft),
        onPickDate: _pickDate,
        sources: _sources,
        onCreateSource: _createSource,
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
      }, _categories),
    ),
  );

  void _openReminderRules() => _push(
    ReminderRulesScreen(
      settings: _settings,
      pushGranted: _notificationsGranted,
      exactTiming: _exactTiming,
      onEnablePush: _requestNotifications,
      onSendTest: () => unawaited(_sendTestNotification()),
      onToggleLead: (lead, on) =>
          widget.settings.save(_settings.withLead(lead, on)),
      onPickTime: _pickRemindTime,
    ),
  );

  /// Which of the two true answers about the device's own backup applies here.
  ///
  /// Read from [defaultTargetPlatform] rather than from `dart:io`, so a test
  /// can put the screen in either platform and check both sentences. Both are
  /// facts the app can stand behind; see [DeviceBackup] for why this is not
  /// the same case as the reminder budget, which prints one number everywhere.
  DeviceBackup get _deviceBackup => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => DeviceBackup.wholeDeviceOnly,
    TargetPlatform.android => DeviceBackup.perAppUnverifiable,
    _ => DeviceBackup.unknown,
  };

  /// Puts one notification on the device so the user can watch it arrive.
  ///
  /// Reports the time and the zone rather than "sent". The user is about to
  /// stare at a phone, and needs to know what they are waiting for and when to
  /// stop waiting; a zone that is not theirs is the answer on a device where
  /// reminders arrive at the wrong hour.
  Future<void> _sendTestNotification() async {
    final TestDelivery sent;
    try {
      sent = await widget.scheduler.sendTest();
    } on Exception catch (error) {
      // The failure worth catching is Android refusing an exact alarm, which
      // throws rather than degrading. Saying so beats a button that looks like
      // it worked.
      if (mounted) _confirm('Could not schedule a test: $error');
      return;
    }
    if (!mounted) return;

    _confirm(
      sent.exact == false
          ? 'Test set for ${sent.at} ${sent.zone}, give or take a few '
                'minutes — this device will not fire on the minute.'
          : 'Test set for ${sent.at} ${sent.zone}.',
    );
  }

  /// The service list. Pushed rather than a tab: it is the answer to "where did
  /// my Netflix go", which is a question asked from Upcoming, and a fifth tab
  /// for it would put a rarely-visited screen in the thumb's way forever.
  void _openServices() => _push(
    // Its own stream rather than the snapshot this route was pushed with. The
    // switch on every row writes to the database, and a pushed route holding a
    // captured list would show the switch flipping straight back.
    StreamBuilder<List<TrackedItem>>(
      initialData: _items,
      stream: widget.repository.observeAll(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <TrackedItem>[];
        return ServicesScreen(
          groups: ServicesPresenter.groups(
            items,
            _categories,
            LocalDate.today(),
          ),
          onOpen: _openItemById,
          onToggle: (id, on) => unawaited(widget.repository.setPaused(id, !on)),
          onAdd: () {
            Navigator.of(context).maybePop();
            _openAdd();
          },
        );
      },
    ),
  );

  void _openSources() => _push(
    StreamBuilder<List<PaymentSource>>(
      initialData: _sources,
      stream: widget.repository.observeSources(),
      builder: (context, snapshot) {
        final sources = snapshot.data ?? const <PaymentSource>[];
        return SourcesScreen(
          rows: ServicesPresenter.sourceRows(sources, _items),
          onAdd: (name, glyph) => unawaited(_createSource(name, glyph)),
          onRemove: (id) => unawaited(widget.repository.deleteSource(id)),
        );
      },
    ),
  );

  /// Creates a source and returns its id so the form that asked can select it.
  ///
  /// The id is the microsecond clock, matching how items are keyed. Two sources
  /// created in the same microsecond would collide; a user tapping "Add source"
  /// twice in one microsecond is not a case worth a uuid dependency.
  Future<String?> _createSource(String name, SourceGlyph glyph) async {
    final id = 'src${DateTime.now().microsecondsSinceEpoch}';
    await widget.repository.upsertSource(
      PaymentSource(id: id, name: name, glyph: glyph),
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return id;
  }

  void _setYearlyChoice(String itemId, YearlyChoice choice) {
    unawaited(widget.repository.setYearlyChoice(itemId, choice));
    if (choice == YearlyChoice.remind) {
      _confirm('The renewal reminder will mention the yearly price.');
    }
  }

  void _openItemById(String id) {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item != null) _openItem(item);
  }

  /// Deletes from a list, where the row that was tapped is the only thing
  /// naming what is about to go. Goes through the same ask as the detail
  /// screen: the button that opens it sits under "Cancelled", and a cancelled
  /// service is exactly the one whose recorded payments still matter.
  Future<void> _deleteById(String id) async {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    await _delete(item, pop: false);
  }

  /// Leaves for the page where a service is actually cancelled.
  ///
  /// Routed through the same lifecycle hook as the manage button, so coming
  /// back from a cancel page also offers to record the date. Someone who
  /// changed their mind at the last step is exactly the person whose renewal
  /// date is now visible on screen and about to be forgotten.
  Future<void> _openCancelPage(String itemId, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    _openedProviderPageFor = itemId;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    _openedProviderPageFor = null;
    _confirm('Could not open that page.');
  }

  /// A form opened over everything: no tab bar.
  ///
  /// Add and edit are the two screens the hand-off draws without the bar, and
  /// the reason is in their own top-right corner: they say `Cancel`, so they
  /// are a task with a way out rather than a place. Leaving the bar on would
  /// offer a second way out that silently discards what was typed.
  void _pushForm(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlassBackground(
          child: Scaffold(
            backgroundColor: const Color(0x00000000),
            body: SafeArea(bottom: false, child: screen),
          ),
        ),
      ),
    );
  }

  /// A screen opened by tapping a row: the tab bar stays.
  ///
  /// The hand-off screenshots settle this. Item detail, All services,
  /// Reminders and History all still show the bar, so none of them is a place
  /// the user has been taken *out* of the app to — they are still inside the
  /// tab they came from, one level down. Only the add and edit forms drop the
  /// bar, and those say `Cancel` instead of `Back` for the same reason.
  ///
  /// Wrapped in a whole [AppShell] rather than only the bar, because the shell
  /// is also what paints the gradient: a pushed route is a new opaque layer,
  /// so a screen that does not paint the ground itself lands on nothing.
  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppShell(
          current: _tab,
          // A tab tapped from one level down means "take me to that tab", not
          // "put that tab behind this screen". Unwind to the shell first.
          onSelect: (tab) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            setState(() => _tab = tab);
          },
          onAdd: _openAdd,
          child: screen,
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

    // `.on` rather than the plain constructor: a new item takes the shelf's
    // reminder defaults, and the shelf is the only thing that knows them.
    final item = TrackedItem.on(
      draft.category,
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
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

    _saves++;
    if (_shouldAskForNotifications) {
      await _askForNotifications(item);
      return;
    }

    // An item dated a year out lands in a collapsed fold, so saving it looks
    // exactly like saving nothing. Say where it went.
    _confirm(_savedMessage(item));
  }

  /// First save, then not until two more have gone in after a decline.
  bool get _shouldAskForNotifications =>
      !_notificationsGranted &&
      (_saves == 1 ||
          (_declinedAtSave != null && _saves - _declinedAtSave! >= 2));

  /// The sheet, worded with this item's own dates.
  ///
  /// The sentence is the whole point: the user has just typed a date they are
  /// afraid of forgetting, and the prompt reads it back with the reminder date
  /// and the card that pays for it. A generic "allow notifications?" at this
  /// moment throws that away.
  Future<void> _askForNotifications(TrackedItem item) async {
    final today = LocalDate.today();
    final lead = item.leadDays.isEmpty
        ? 0
        : item.leadDays.reduce((a, b) => a > b ? a : b);
    final fireOn = item.actBy.minusDays(lead);
    final source = _sourcesById[item.paymentSourceId];

    final money = item.money == null
        ? ''
        : (item.isTrialOn(today)
              ? ' · then ${MoneyFormat.full(item.money!)}'
              : ' · ${MoneyFormat.full(item.money!)}');
    final from = source == null ? '' : ' from ${source.name}';

    final line = lead == 0
        ? 'Notification on ${MoneyFormat.shortDate(fireOn)}, the day it '
              'happens$money$from.'
        : 'Notification on ${MoneyFormat.shortDate(fireOn)} — '
              '${ItemPresenter.leadLabel(lead).toLowerCase()} '
              '(${MoneyFormat.shortDate(item.actBy)})$money$from.';

    final allowed = await NotificationAsk.show(
      context,
      itemName: item.name,
      iconName: item.iconName,
      title: item.isTrialOn(today)
          ? 'Remind you before the trial ends?'
          : 'Remind you before ${item.name} charges?',
      line: line,
    );
    if (!mounted) return;

    if (allowed == true) {
      await _requestNotifications();
      if (!mounted) return;
      _confirm('Reminder set for ${MoneyFormat.shortDate(fireOn)}.');
      return;
    }

    _declinedAtSave = _saves;
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

  /// Leaves for the page that actually holds this subscription.
  ///
  /// The tap is also the answer to a question the app never asks out loud.
  /// Someone who opens the App Store listing has just said where they bought
  /// the thing, so it is written down and the alternatives stop being offered.
  /// Asking up front instead would put a question about billing plumbing
  /// between the user and adding their first item.
  Future<void> _openManage(TrackedItem item, ManageAction action) async {
    var current = item;
    final learned = current.purchaseChannel != action.records;
    if (learned) {
      current = current.copyWith(purchaseChannel: action.records);
      await widget.repository.upsert(
        current,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }
    if (!mounted) return;

    // Only when something on the screen behind actually changed. That screen
    // is a snapshot taken before the channel was recorded, so it would still
    // be offering the choice the user has just made -- but rebuilding it on
    // every visit would throw the scroll position away to no purpose, and put
    // a route transition on screen at the moment the browser opens.
    if (learned) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      _openItem(current);
    }

    final uri = Uri.tryParse(action.url);
    if (uri == null) return;

    _openedProviderPageFor = current.id;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    // Nothing on the device would take the link. Say so rather than leaving
    // the user tapping a button that does nothing -- the exact failure mode
    // that ruled out a USSD button for prepaid SIMs.
    _openedProviderPageFor = null;
    _confirm('Could not open that page.');
  }

  /// The prompt on the way back in.
  ///
  /// One question, one action, and no second attempt. The user has just seen
  /// the real renewal date; a date they type now is [DateSource.userConfirmed]
  /// rather than a guess, which is the strongest thing this app can ever say
  /// about a date.
  void _offerRenewalDate(TrackedItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Did you see the renewal date?',
          style: SubdockText.rowValue.copyWith(color: SubdockColors.card),
        ),
        backgroundColor: SubdockColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SubdockRadius.card),
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Enter date',
          textColor: SubdockColors.card,
          onPressed: () => unawaited(_confirmRenewalDate(item)),
        ),
      ),
    );
  }

  Future<void> _confirmRenewalDate(TrackedItem item) async {
    final picked = await _pickDate(item.expiresOn);
    if (picked == null || !mounted) return;

    // Routed through the same draft the editor uses so the anchor moves with
    // the date. Writing `expiresOn` on its own would leave an instalment plan
    // counting from the old day of the month.
    final moved = DraftItem(
      name: item.name,
      expiresOn: picked,
      category: _categories[item.categoryId],
      iconName: item.iconName,
      cycle: item.cycle,
      repeatCount: item.repeatCount,
      amountMinor: item.amountMinor,
      currency: item.currency,
      leadDays: item.leadDays,
    ).applyTo(item);

    // The one override. `applyTo` marks a retyped date as remembered, which is
    // right everywhere else and wrong here: this one was read off the
    // provider's own page a moment ago.
    final updated = moved.copyWith(dateSource: DateSource.userConfirmed);

    await widget.repository.upsert(
      updated,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;

    // Back to the list and straight into the item, rather than popping
    // whatever happens to be on top. The prompt lives for eight seconds and
    // the user may have wandered somewhere else in them; this lands on the
    // item they just dated wherever they answered from.
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    _openItem(updated);
    _confirm('Saved ${MoneyFormat.date(picked)} as confirmed.');
  }

  /// Hands the whole database to the system share sheet as one JSON file.
  ///
  /// The app never chooses where it lands. There is no folder inside it and no
  /// account behind it, so the only place a backup is safe is somewhere the
  /// user already keeps things -- Files, iCloud, a chat with themselves -- and
  /// the share sheet is the only thing that can put it there.
  Future<void> _exportBackup() async {
    final at = DateTime.now();
    final backup = await widget.backups.read(clock: at);
    if (!mounted) return;

    // Anchors the popover on iPad, where a share sheet with nothing to point
    // at is a crash rather than a centred dialog.
    final box = context.findRenderObject() as RenderBox?;

    try {
      final saved = await widget.files.save(
        BackupCodec.encode(backup),
        BackupStore.fileNameFor(at),
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      // Nothing said on a dismissal, and nothing recorded either. The user
      // closed the sheet without picking anywhere, so no file left the phone;
      // both a "Saved" message and a date under `Last backup` would stand for
      // something that did not happen.
      if (!saved) return;
      await widget.backups.markSaved(LocalDate.fromDateTime(at));
      if (mounted) _confirm('Backed up ${backup.summary}.');
    } on Exception catch (error) {
      if (mounted) _confirm('Could not export: $error');
    }
  }

  /// The restore offered on an empty database.
  ///
  /// Looks in the cloud first, because someone staring at this screen has just
  /// reinstalled or moved phone, and the copy the app kept for them is the one
  /// they are most likely to want. Anything other than finding it falls
  /// through to the file picker rather than stopping with an explanation: they
  /// came here to get their list back, not to hear about iCloud.
  Future<void> _restoreOnArrival() async {
    if (widget.cloud.isSupported) {
      final fetch = await widget.cloud.latest();
      if (!mounted) return;
      if (fetch.copy case final copy?) {
        await _restoreFrom(copy.contents);
        return;
      }
    }
    await _importBackup();
  }

  /// Restores the copy the app keeps in the user's own cloud.
  ///
  /// The answer to "it says Saved, so how do I get it back". A file sitting in
  /// iCloud Drive that the user has to find in the Files app is a backup only
  /// for people who already know it is there, and the app knew and did not say.
  Future<void> _importFromCloud() async {
    final fetch = await widget.cloud.latest();
    if (!mounted) return;

    switch (fetch.state) {
      case CloudState.saved:
        break;
      case CloudState.missing:
        _confirm('There is no copy in iCloud yet.');
        return;
      case CloudState.signedOut:
        _confirm('Sign in to iCloud to reach the copy kept there.');
        return;
      default:
        _confirm('Could not read iCloud: ${fetch.detail ?? "unknown error"}.');
        return;
    }

    final copy = fetch.copy;
    if (copy == null) return;
    await _restoreFrom(copy.contents);
  }

  /// Reads a backup back in, replacing everything.
  ///
  /// Three steps that must stay in this order: read the file, then ask, then
  /// write. Asking first would put a destructive question on screen before the
  /// app knows whether the file is even readable, and the answer to "replace 12
  /// items with what?" has to name what.
  Future<void> _importBackup() async {
    final String? text;
    try {
      text = await widget.files.pick();
    } on Exception catch (error) {
      if (mounted) _confirm('Could not open that file: $error');
      return;
    }
    if (text == null || !mounted) return;
    await _restoreFrom(text);
  }

  /// Everything after the bytes arrive, whichever source handed them over.
  ///
  /// Shared on purpose. A copy out of iCloud and a copy off a file the user
  /// picked destroy exactly the same rows, so they must ask exactly the same
  /// question first; two paths would eventually grow two different warnings.
  Future<void> _restoreFrom(String text) async {
    final Backup backup;
    try {
      backup = BackupCodec.decode(text);
    } on BackupFormatException catch (error) {
      _confirm(error.message);
      return;
    }

    // Counted before the write, obviously, but also *named* on the sheet: the
    // rows about to go are ones the user typed and there is nowhere to undo
    // this from.
    final losing = _items.isEmpty
        ? null
        : '${_items.length} ${_items.length == 1 ? "item" : "items"}';

    final confirmed = await RestoreAsk.show(
      context,
      incoming: backup.summary,
      existing: losing,
      takenOn: _takenOn(backup.exportedAt),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.backups.restore(backup);
    } on Exception catch (error) {
      if (mounted) _confirm('Could not restore: $error');
      return;
    }

    // The reminders on the device were planned from rows that no longer exist.
    // The streams re-plan on their own, but the signature guard would skip the
    // re-apply whenever the new plan happens to match the old one.
    _appliedSignature = '';
    if (mounted) _confirm('Restored ${backup.summary}.');
  }

  /// `taken 25/08/2026`, or null when the file does not say.
  ///
  /// Shown because someone with three backups in a folder picks between them by
  /// date, and the file name is not visible from inside the picker's result.
  static String? _takenOn(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return null;
    return 'taken ${MoneyFormat.date(LocalDate.fromDateTime(at.toLocal()))}';
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

  /// Deletes an item, once the user has said so on a sheet that named the
  /// cost.
  ///
  /// Asking is not politeness here. The row carries payments the user typed in
  /// by hand and `ON DELETE CASCADE` takes them with it, and there is no
  /// account, no server and no undo to get them back from — a stray tap on a
  /// quiet button is the whole loss.
  Future<void> _delete(TrackedItem item, {bool pop = true}) async {
    final confirmed = await DeleteAsk.show(
      context,
      name: item.name,
      reminderCount: _plan.alerts.where((a) => a.itemId == item.id).length,
      paymentCount: _history.where((e) => e.itemId == item.id).length,
    );
    if (confirmed != true) return;

    await widget.repository.delete(item.id);
    if (pop && mounted) Navigator.of(context).maybePop();
  }
}
