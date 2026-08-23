import 'package:flutter/material.dart';

import 'package:subdock/ui/icons.dart';
import 'package:subdock/ui/theme.dart';

/// The uppercase heading that sits above a card, outside it.
class SectionLabel extends StatelessWidget {
  final String text;

  /// The first label on a screen sits closer to the title than a label that is
  /// separating two cards.
  final bool tight;

  const SectionLabel(this.text, {super.key, this.tight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: tight ? 16 : SubdockSpacing.sectionTop,
        bottom: SubdockSpacing.sectionBottom,
      ),
      child: Text(text.toUpperCase(), style: SubdockText.sectionLabel),
    );
  }
}

/// The white container everything sits in.
///
/// There is no border. The card is told apart from the grey ground purely by
/// [SubdockShadow.card], which is why this is a single widget rather than a
/// decoration each screen repeats: one card drawn with a border, or with a
/// flatter shadow, reads as a different surface class entirely.
class GroupedCard extends StatelessWidget {
  final List<Widget> children;

  /// Set to make the card one block instead of a stack of ruled rows. A block
  /// card gets no hairlines: its children are lines of a single thought, and
  /// ruling between them would slice one paragraph into three rows.
  final EdgeInsetsGeometry? padding;

  final double radius;
  final Color color;
  final List<BoxShadow> shadow;

  const GroupedCard({
    super.key,
    required this.children,
    this.padding,
    this.radius = SubdockRadius.card,
    this.color = SubdockColors.card,
    this.shadow = SubdockShadow.card,
  });

  @override
  Widget build(BuildContext context) {
    final ruled = padding == null;

    final interleaved = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (ruled && i > 0) {
        interleaved.add(
          const Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
        );
      }
      interleaved.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: interleaved,
      ),
    );
  }
}

/// The small downward triangle on a field that opens a picker.
///
/// Drawn rather than set as `▾`. Neither bundled face carries U+25BE, so the
/// character falls back to whatever the platform happens to have — a different
/// weight and a different size on every device, and nothing at all in a test.
class Caret extends StatelessWidget {
  final Color color;
  final double size;

  /// Points up instead of down. Used where the caret reports state rather than
  /// affordance: a section that is already open.
  final bool up;

  const Caret({
    super.key,
    this.color = SubdockColors.inkMuted,
    this.size = 9,
    this.up = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.55),
      painter: _CaretPainter(color, up),
    );
  }
}

class _CaretPainter extends CustomPainter {
  final Color color;
  final bool up;

  const _CaretPainter(this.color, this.up);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.color != color || old.up != up;
}

/// A label on the left, a value on the right. The workhorse of the detail,
/// settings and review screens.
class DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  /// True for a date, an amount, a count — anything the reader lines up
  /// against the same field on another row.
  final bool monoValue;

  /// A row that leads somewhere shows a chevron and reads in full ink; a row
  /// that states a fact does neither.
  final VoidCallback? onTap;
  final bool chevron;

  final Color? valueColor;

  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.monoValue = false,
    this.onTap,
    this.chevron = false,
    this.valueColor,
  });

  /// A settings entry: full-ink label, chevron, nothing else.
  const DetailRow.nav({
    super.key,
    required this.label,
    this.value,
    required this.onTap,
  }) : monoValue = false,
       chevron = true,
       valueColor = null;

  @override
  Widget build(BuildContext context) {
    final base = monoValue ? SubdockText.monoValue : SubdockText.rowValue;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SubdockSpacing.rowH,
          vertical: chevron ? 15 : SubdockSpacing.rowV,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: chevron ? SubdockText.rowLink : SubdockText.rowLabel,
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: chevron
                      ? SubdockText.rowLabel.copyWith(fontSize: 12)
                      : (valueColor == null
                            ? base
                            : base.copyWith(color: valueColor)),
                ),
              ),
            if (chevron) ...[
              const SizedBox(width: 8),
              const Text(
                '›',
                style: TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 12,
                  height: 1,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded square that stands in for a service's mark.
///
/// Filled with the page ground rather than white, so on a white card it reads
/// as a hole rather than as another card. Carries the item's initial until
/// there is a real logo to put in it — an empty square beside a name reads as
/// an image that failed to load.
class ServiceTile extends StatelessWidget {
  final String name;

  /// An explicit icon key. When null the name is asked, and when the name has
  /// nothing to say its first letter is drawn.
  final String? iconName;

  final double size;
  final double radius;
  final double fontSize;

  /// Set on the add form, where the tile is the way into the icon gallery.
  final VoidCallback? onTap;

  const ServiceTile(
    this.name, {
    super.key,
    this.iconName,
    this.size = 34,
    this.radius = SubdockRadius.chip,
    this.fontSize = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    // With no name yet there is no letter to draw and nothing to detect from,
    // and an empty square beside an empty field reads as an image that failed
    // to load. The neutral mark says "this is the icon, and you can tap it".
    final key = iconName ?? SubdockIcons.detect(trimmed);
    final icon = SubdockIcons.resolve(
      trimmed.isEmpty ? (key ?? SubdockIcons.fallback) : key,
    );
    final letter = trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();

    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SubdockColors.canvas,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SubdockColors.hairline),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.52, color: SubdockColors.inkMuted)
          : Text(
              letter,
              style: SubdockText.tileLetter.copyWith(fontSize: fontSize),
            ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: tile,
    );
  }
}

/// The filled action. There is one accent in this design, so a screen showing
/// two of these has a hierarchy problem rather than a styling one.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        boxShadow: enabled ? SubdockShadow.card : const [],
      ),
      child: Material(
        color: enabled ? SubdockColors.accent : SubdockColors.accentTrack,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SubdockRadius.card),
          child: Container(
            // Horizontal padding matters only when the button is sized to its
            // label rather than to the screen: the empty state's one button is
            // the case, and without it the words touch the accent's edge.
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SubdockText.button.copyWith(
                color: enabled ? SubdockColors.card : SubdockColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The second action: a white card of the same size, one elevation lower.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SecondaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        boxShadow: SubdockShadow.soft,
      ),
      child: Material(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SubdockRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SubdockText.button.copyWith(color: SubdockColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The third action: no card at all.
///
/// This is where the design puts the one thing on a screen that undoes it —
/// cancel the subscription, stop after this payment. It is reachable without
/// being a target the thumb finds by accident.
class QuietButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  const QuietButton(
    this.label, {
    super.key,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(SubdockRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: danger
              ? SubdockText.quietAction.copyWith(color: SubdockColors.danger)
              : SubdockText.quietAction,
        ),
      ),
    );
  }
}

/// A selectable pill: date shortcuts, reminder leads, history filters.
class ChoiceChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const ChoiceChipPill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        boxShadow: selected ? const [] : SubdockShadow.soft,
      ),
      child: Material(
        color: selected ? SubdockColors.accent : SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SubdockRadius.chip),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Text(
              label,
              style: selected ? SubdockText.chipSelected : SubdockText.chip,
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of chips that scrolls sideways and runs off both edges of the
/// screen.
///
/// The hand-off is specific about this: the Date and Remind me rows are a
/// single row that bleeds to the edge of the phone, not a wrapping block. A
/// wrap re-flows into two or three lines as options are added and the form
/// grows a different height per item; a rail stays one line forever, and the
/// half-chip cut off at the right edge is what tells the reader to push it.
///
/// Because the rail supplies its own gutters, the screen that holds it must
/// not — put it outside the body's horizontal padding.
class ChipRail extends StatelessWidget {
  final List<Widget> children;

  const ChipRail({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.screenH,
        // The chips carry a soft shadow, and a scroll view clips to its own
        // bounds; without the room the shadow is sliced off along the line.
        vertical: 4,
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row of pills that divide the width between them: Monthly / Yearly / Once.
///
/// Separate from [ChoiceChipPill] because the options are exhaustive and
/// mutually exclusive, and equal widths are what say so.
class SegmentedRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelect;

  const SegmentedRow({
    super.key,
    required this.labels,
    required this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SubdockRadius.control),
                boxShadow: i == selected ? const [] : SubdockShadow.soft,
              ),
              child: Material(
                color: i == selected
                    ? SubdockColors.accent
                    : SubdockColors.card,
                borderRadius: BorderRadius.circular(SubdockRadius.control),
                child: InkWell(
                  onTap: onSelect == null ? null : () => onSelect!(i),
                  borderRadius: BorderRadius.circular(SubdockRadius.control),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: i == selected
                          ? SubdockText.chipSelected
                          : SubdockText.chip,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The white box a field's contents sit in. One elevation below a card.
class FieldBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Drawn while the field has focus: the accent as a ring rather than a fill.
  final bool focused;

  const FieldBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.field),
        boxShadow: focused ? SubdockShadow.card : SubdockShadow.soft,
        border: focused
            ? Border.all(color: SubdockColors.accent, width: 1.5)
            : null,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// A label above a field, with the field under it.
class Field extends StatelessWidget {
  final String label;
  final Widget child;

  /// Set when the child supplies its own gutters and runs to the screen edge
  /// — a [ChipRail]. The label still needs the gutter, so it keeps it.
  final bool bleed;

  const Field({
    super.key,
    required this.label,
    required this.child,
    this.bleed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: bleed ? SubdockSpacing.screenH : 0,
            right: bleed ? SubdockSpacing.screenH : 0,
            bottom: SubdockSpacing.labelToControl,
          ),
          child: Text(label.toUpperCase(), style: SubdockText.sectionLabel),
        ),
        child,
      ],
    );
  }
}

/// A field whose value is picked from a list: category, repeat count.
class PickerField extends StatelessWidget {
  final String value;
  final bool placeholder;
  final VoidCallback? onTap;

  const PickerField({
    super.key,
    required this.value,
    this.placeholder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SubdockRadius.field),
      child: FieldBox(
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: placeholder
                    ? SubdockText.fieldValue.copyWith(
                        color: SubdockColors.inkMuted,
                      )
                    : SubdockText.fieldValue,
              ),
            ),
            const SizedBox(width: 8),
            const Caret(),
          ],
        ),
      ),
    );
  }
}

/// The iOS-shaped switch, drawn here so it carries the app's accent rather
/// than Material's.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? SubdockColors.accent : SubdockColors.accentTrack,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Container(
            width: 19,
            height: 19,
            decoration: const BoxDecoration(
              color: SubdockColors.card,
              shape: BoxShape.circle,
              boxShadow: SubdockShadow.knob,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row carrying a switch. Its label is full ink: it is a control, not a fact.
class ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.rowH,
        vertical: SubdockSpacing.rowV,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: SubdockText.rowLink)),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A short explanatory line under a card. Never a tooltip: the design puts the
/// caveat on screen where it cannot be missed.
class Footnote extends StatelessWidget {
  final String text;

  const Footnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text, style: SubdockText.footnote),
    );
  }
}
