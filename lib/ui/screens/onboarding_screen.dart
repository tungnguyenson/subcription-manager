import 'package:flutter/material.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The one screen that explains the idea, shown once.
///
/// Three rows, in the order the user will do them: add something, choose when
/// to be told, let the phone tell you. The last one is the permission ask, and
/// it is on this screen rather than at first launch because a permission
/// prompt with no explanation in front of it is how an app earns a permanent
/// "no".
class OnboardingScreen extends StatelessWidget {
  final bool notificationsGranted;
  final VoidCallback? onAllowNotifications;
  final VoidCallback? onStart;

  /// Reads a backup file back in, without going through the app first.
  ///
  /// This screen is what someone sees after reinstalling, or on a new phone,
  /// which is exactly the moment a backup is worth having. Leaving the only
  /// way in buried under Settings means the person who needs it most has to
  /// walk past a screen about adding their first item to reach it.
  final VoidCallback? onRestore;

  const OnboardingScreen({
    super.key,
    this.notificationsGranted = false,
    this.onAllowNotifications,
    this.onStart,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 52, 22, 12),
            children: [
              Text(
                'Never miss a due date again.',
                style: SubdockText.onboardTitle,
              ),
              const SizedBox(height: 14),
              Text(
                'Subdock keeps every bill, trial and SIM date in one list and '
                'reminds you before it hits.',
                style: SubdockText.body,
              ),
              const SizedBox(height: 30),
              const _Feature(
                mark: _Mark.plus,
                title: 'Add what you pay for',
                body: 'Bills, trials, SIM, insurance — anything with a date.',
              ),
              const SizedBox(height: 12),
              const _Feature(
                mark: _Mark.clock,
                title: 'Pick when to be reminded',
                body: '7, 3 or 1 day before, or on the day itself.',
              ),
              const SizedBox(height: 12),
              _Feature(
                mark: _Mark.badge,
                title: notificationsGranted
                    ? 'Notifications are on'
                    : 'Allow notifications',
                body: notificationsGranted
                    ? 'You will be told before each date, at 08:30.'
                    : 'Without it the list stays silent.',
                onTap: notificationsGranted ? null : onAllowNotifications,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton('Get started', onPressed: onStart),
              // Quiet, not a second filled button. Most people opening this
              // screen are starting from nothing and the restore is not for
              // them; the ones it is for are looking for it and will find it.
              if (onRestore != null) ...[
                const SizedBox(height: 4),
                QuietButton('I already have a backup', onPressed: onRestore),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The three marks are drawn here rather than pulled from an icon set. The
/// rest of the app is close to pure type, and a Material icon or an SF Symbol
/// would import a different drawing language into the first screen the user
/// ever sees.
enum _Mark { plus, clock, badge }

class _Feature extends StatelessWidget {
  final _Mark mark;
  final String title;
  final String body;
  final VoidCallback? onTap;

  const _Feature({
    required this.mark,
    required this.title,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      padding: EdgeInsets.zero,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SubdockRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SubdockColors.canvas,
                    borderRadius: BorderRadius.circular(
                      SubdockRadius.featureTile,
                    ),
                    border: Border.all(color: SubdockColors.hairline),
                  ),
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: _MarkPainter(mark),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: SubdockText.family,
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: SubdockWeight.medium,
                          letterSpacing: -0.14,
                          color: SubdockColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: SubdockText.itemSubtitle.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  final _Mark mark;

  const _MarkPainter(this.mark);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = SubdockColors.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fill = Paint()..color = SubdockColors.accent;
    final centre = Offset(size.width / 2, size.height / 2);

    switch (mark) {
      case _Mark.plus:
        canvas.drawLine(
          Offset(1, centre.dy),
          Offset(size.width - 1, centre.dy),
          stroke,
        );
        canvas.drawLine(
          Offset(centre.dx, 1),
          Offset(centre.dx, size.height - 1),
          stroke,
        );

      case _Mark.clock:
        canvas.drawCircle(centre, size.width / 2 - 1, stroke);
        // Hands at roughly ten past twelve — the angle a clock face is drawn
        // at everywhere, and the one that reads as a clock at 20px.
        canvas.drawLine(centre, Offset(centre.dx, centre.dy - 4), stroke);
        canvas.drawLine(centre, Offset(centre.dx + 3.5, centre.dy), stroke);

      case _Mark.badge:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 3, size.width - 5, size.height - 5),
            const Radius.circular(5),
          ),
          stroke,
        );
        // The unread dot, in the one colour on this screen that is not the
        // accent: it is the thing that will interrupt you.
        canvas.drawCircle(
          Offset(size.width - 4, 4),
          4,
          fill..color = SubdockColors.danger,
        );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.mark != mark;
}
