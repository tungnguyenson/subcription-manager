import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/reminder_timeline.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// "What happens next" for one item, drawn as a single column of dated stops.
///
/// It replaced a one-line `Next reminder 29/08 at 08:30` on the detail screen,
/// which could only ever name the soonest alert. That was fine until the user
/// pressed *Remind me again in 3 days*, which does not move the ladder — it
/// adds one more alert beside it. With one line to say it in, the app looked
/// like it had rescheduled everything onto the new date, and there was nowhere
/// on the screen that said otherwise. See trap 29 in CLAUDE.md.
///
/// The deadline sits in the column with the reminders, not above them, so a
/// snooze that lands past it reads as what it is.
class ReminderTimelineCard extends StatelessWidget {
  final ReminderTimeline timeline;
  final LocalDate today;

  const ReminderTimelineCard({
    super.key,
    required this.timeline,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One block card, not ruled rows. A hairline between every stop would
        // cut the connector that makes this read as a single run of time.
        GroupedCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SubdockSpacing.rowH,
            vertical: 4,
          ),
          children: [
            for (var i = 0; i < timeline.stops.length; i++)
              _StopRow(
                stop: timeline.stops[i],
                today: today,
                first: i == 0,
                last: i == timeline.stops.length - 1,
              ),
          ],
        ),
        if (timeline.note case final note?) Footnote(note),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final TimelineStop stop;
  final LocalDate today;
  final bool first;
  final bool last;

  const _StopRow({
    required this.stop,
    required this.today,
    required this.first,
    required this.last,
  });

  /// Width of the date gutter. Fixed rather than intrinsic: the dates have to
  /// line up into a column for the run to read as a timeline, and one row
  /// carrying a full `28/08/2027` must not shove the other rows sideways.
  static const double _dateWidth = 62;

  @override
  Widget build(BuildContext context) {
    final marker = stop.kind == TimelineKind.deadline;
    final trial = stop.kind == TimelineKind.trial;
    final muted = stop.isPast;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _dateWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                ReminderTimelinePresenter.dateLabel(stop.date, today),
                style: SubdockText.monoValue.copyWith(
                  color: muted
                      ? SubdockColors.inkMuted
                      : marker
                      ? SubdockColors.ink
                      : SubdockColors.inkSecondary,
                ),
              ),
            ),
          ),
          _Rail(stop: stop, first: first, last: last),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.label,
                    // The trial row carries the accent, because it is the one
                    // row that is true right now. The card it replaced was
                    // accented all over for the same reason.
                    style: trial
                        ? SubdockText.rowLabel.copyWith(
                            fontWeight: SubdockWeight.medium,
                            color: SubdockColors.accent,
                          )
                        : marker
                        ? SubdockText.rowLabel.copyWith(
                            fontWeight: SubdockWeight.medium,
                            color: muted
                                ? SubdockColors.inkMuted
                                : SubdockColors.ink,
                          )
                        : SubdockText.rowLabel,
                  ),
                  if (_detail() case final detail?) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: stop.isNext
                          ? SubdockText.caption.copyWith(
                              color: SubdockColors.accent,
                            )
                          : SubdockText.caption,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The second line: what kind of thing this row is.
  ///
  /// The word *Reminder* is spelled out rather than left to a bare `08:30`,
  /// and the deadline carries its amount, because those two together are the
  /// only thing telling the user which of these dates sends a notification and
  /// which one takes money. A column of dates and sentences alone left them
  /// counting rings.
  ///
  /// A deadline and a trial row get their wording from the presenter: neither
  /// is a notification, so neither has a send time to print or a "next" to be.
  String? _detail() {
    if (stop.kind == TimelineKind.deadline || stop.kind == TimelineKind.trial) {
      return stop.detail;
    }
    final at = stop.time;
    final label = at == null
        ? S.t.timelineReminder
        : S.t.timelineReminderAt('$at');
    return stop.isNext ? S.t.timelineNext(label) : label;
  }
}

/// The dot and the line through it.
///
/// Drawn rather than composed from characters, for the reason the [Caret] is:
/// neither bundled face carries the box-drawing and bullet glyphs this needs,
/// so a text version renders differently on every device and not at all under
/// `flutter test`.
class _Rail extends StatelessWidget {
  final TimelineStop stop;
  final bool first;
  final bool last;

  const _Rail({required this.stop, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: CustomPaint(
        painter: _RailPainter(
          hollow:
              stop.kind == TimelineKind.deadline ||
              stop.kind == TimelineKind.trial,
          accent: stop.isNext || stop.kind == TimelineKind.trial,
          muted: stop.isPast,
          top: !first,
          bottom: !last,
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  /// A ring rather than a dot: the two rows that are not notifications, so
  /// they are legible as such without reading the words. A deadline and the
  /// trial row both take it.
  final bool hollow;

  /// The accent colour: the next notification, and the trial row. Solid dot or
  /// ring is [hollow]'s business -- this is only the colour, so the one filled
  /// accent dot still reads as the single thing coming up.
  final bool accent;

  final bool muted;
  final bool top;
  final bool bottom;

  const _RailPainter({
    required this.hollow,
    required this.accent,
    required this.muted,
    required this.top,
    required this.bottom,
  });

  /// Where the dot sits from the top of the row. Matched to the baseline of
  /// the date beside it rather than centred in the row, because rows differ in
  /// height and a dot that floats with the text block drifts out of the column.
  static const double _dotY = 19;
  static const double _radius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final line = Paint()
      ..color = SubdockColors.hairline
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    if (top) canvas.drawLine(Offset(x, 0), Offset(x, _dotY - _radius), line);
    if (bottom) {
      canvas.drawLine(Offset(x, _dotY + _radius), Offset(x, size.height), line);
    }

    final colour = muted
        ? SubdockColors.inkMuted
        : accent
        ? SubdockColors.accent
        : SubdockColors.inkSecondary;

    if (hollow) {
      canvas.drawCircle(
        Offset(x, _dotY),
        _radius,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawCircle(Offset(x, _dotY), _radius, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.accent != accent ||
      old.hollow != hollow ||
      old.muted != muted ||
      old.top != top ||
      old.bottom != bottom;
}
