import 'package:flutter/material.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/domain/fx.dart';

class SettingsScreen extends StatelessWidget {
  /// Alerts the planner had to leave out. Shown at the top, not buried in a
  /// log: the platform drops the furthest-out pending notifications silently,
  /// and the user has no other way to learn that a reminder they are relying
  /// on was never actually scheduled.
  final List<String> droppedReminders;

  final String currencyLabel;
  final String languageLabel;

  final VoidCallback? onOpenCurrency;
  final VoidCallback? onOpenLanguage;

  /// `8 · 2 off`. Answers "how much is in there" without opening the screen,
  /// and the `off` half is the only place outside Upcoming that says anything
  /// has been paused.
  final String? servicesLine;

  /// `3`, or `None`.
  final String? sourcesLine;

  /// What the backup card says: when the last one was, whether the device
  /// keeps a copy of its own, and whether that is worth warning about.
  ///
  /// Null only where a caller has nothing to say, which in practice is a test
  /// building this screen for some other reason. The card still draws its two
  /// actions; it just cannot report state it was not given.
  final BackupView? backup;

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenSources;
  final VoidCallback? onOpenReminders;
  final VoidCallback? onOpenHistory;

  /// Hands the whole list to the system share sheet as one file.
  ///
  /// Still here because the warning banner offers it: someone told their list
  /// has never been copied anywhere should not have to find the right screen
  /// first.
  final VoidCallback? onExport;

  /// The two channels, each on its own screen.
  ///
  /// Two rows rather than five. The section used to hold a status, a date and
  /// three actions, two of which replace the whole list; under one heading
  /// that gave the destructive pair the same weight as the date above them,
  /// and neither date said which copy it was about.
  final VoidCallback? onOpenCloudBackup;
  final VoidCallback? onOpenFileBackup;

  /// Which of the two Glass variants the app paints in.
  ///
  /// A three-way tray rather than a switch, because [ThemeChoice.system] is a
  /// real answer: a phone that turns dark at sunset is saying something, and a
  /// switch can only ignore it or fight it.
  final ThemeChoice themeChoice;
  final ValueChanged<ThemeChoice>? onThemeChoice;

  final VoidCallback? onAbout;

  const SettingsScreen({
    super.key,
    this.droppedReminders = const [],
    this.currencyLabel = Fx.defaultBase,
    this.languageLabel = 'English',
    this.onOpenCurrency,
    this.onOpenLanguage,
    this.servicesLine,
    this.sourcesLine,
    this.backup,
    this.onOpenServices,
    this.onOpenSources,
    this.onOpenReminders,
    this.onOpenHistory,
    this.onExport,
    this.onOpenCloudBackup,
    this.onOpenFileBackup,
    this.themeChoice = ThemeChoice.system,
    this.onThemeChoice,
    this.onAbout,
  });

  /// What the tray is actually doing, said out loud.
  ///
  /// The tray shows which of the three is picked; it cannot say that System
  /// means the app will change on its own later, which is the one thing about
  /// this setting a user can be surprised by.
  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        Text(S.t.settingsTitle, style: SubdockText.screenTitle),
        if (droppedReminders.isNotEmpty) ...[
          const SizedBox(height: 18),
          AlertBanner(
            title: S.t.droppedRemindersTitle(droppedReminders.length),
            body: S.t.droppedRemindersBody(
              NotificationPlanner.budget,
              droppedReminders.join(', '),
            ),
          ),
        ],
        // Under the reminder banner rather than above it. That one is about
        // dates that will not arrive; this one is about a list that has not
        // been copied anywhere. Both are things the user cannot find out from
        // any other screen, which is why both are here and not in a footnote.
        if (backup?.warningTitle case final title?) ...[
          const SizedBox(height: 18),
          AlertBanner(
            title: title,
            body: backup?.warningBody ?? '',
            actionLabel: S.t.exportABackup,
            onAction: onExport,
          ),
        ],
        const SizedBox(height: 20),
        GroupedCard(
          children: [
            DetailRow.nav(
              label: S.t.allServices,
              value: servicesLine,
              onTap: onOpenServices,
            ),
            DetailRow.nav(label: S.t.rowReminders, onTap: onOpenReminders),
            DetailRow.nav(
              label: S.t.rowPaymentSources,
              value: sourcesLine,
              onTap: onOpenSources,
            ),
            DetailRow.nav(label: S.t.rowHistory, onTap: onOpenHistory),
            // Destinations now, not value rows. Both were answered once during
            // onboarding, and the row that shows the answer has to be the row
            // that changes it -- a person who picked the wrong one there has
            // nowhere else to go looking.
            DetailRow.nav(
              label: S.t.rowCurrency,
              value: currencyLabel,
              onTap: onOpenCurrency,
            ),
            DetailRow.nav(
              label: S.t.rowLanguage,
              value: languageLabel,
              onTap: onOpenLanguage,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GroupedCard(
          children: [
            // A value row, not a destination, and for the same reason Currency
            // and Language above are: there is no home-screen widget in this
            // build and no screen to configure one, so a chevron here would
            // promise a place that does not exist. The row is still worth
            // having — it answers "can this put my next date on the home
            // screen" without the user hunting for a setting that is not
            // there.
            DetailRow(label: S.t.rowWidget, value: S.t.widgetNotYet),
          ],
        ),
        // Above Backup, not below it. Currency, Language and Widget above are
        // all "what the app shows"; this is the same question asked about
        // colour. Backup is about the data, which is a different subject.
        SectionLabel(S.t.rowAppearance),
        SegmentedRow(
          labels: [S.t.themeSystem, S.t.themeLight, S.t.themeDark],
          selected: themeChoice.index,
          onSelect: onThemeChoice == null
              ? null
              : (i) => onThemeChoice!(ThemeChoice.values[i]),
        ),
        SectionLabel(S.t.sectionBackup),
        GroupedCard(
          children: [
            // Each row carries its own date, and they are different dates: a
            // file exported in May sits where the user put it whatever happens
            // afterwards, while the copy in iCloud is only as recent as the
            // last write that landed. One date beside both rows would report
            // the newer of the two next to whichever the reader looked at.
            //
            // The cloud row first, and absent entirely where the app writes
            // to no cloud at all. Its name comes from the view rather than
            // being written here, because which cloud this is depends on the
            // platform and `iCloud` on an Android phone names a service that
            // is not on the device.
            if (backup?.hasCloud ?? false)
              DetailRow.nav(
                label: backup?.cloudLabel ?? '',
                value: backup?.cloudLine,
                onTap: onOpenCloudBackup,
              ),
            DetailRow.nav(
              label: S.t.rowFile,
              value: backup?.fileLine,
              onTap: onOpenFileBackup,
            ),
          ],
        ),
        // State, not a tutorial — the same rule the reminder screen follows.
        // Answers section 11.2 of the product spec: say whether the database
        // is in the device's own backup, so the user knows what they are
        // trusting. The sentence differs per platform because the truth does;
        // see [DeviceBackup].
        if (backup case final view?) Footnote(view.note),
        // Last on the screen. It is the one row nobody comes to Settings to
        // find: it is read once, by someone reporting a problem, and every
        // other row here is something a user actually came for.
        SectionLabel(S.t.sectionApp),
        GroupedCard(
          children: [DetailRow.nav(label: S.t.rowAbout, onTap: onAbout)],
        ),
      ],
    );
  }
}
