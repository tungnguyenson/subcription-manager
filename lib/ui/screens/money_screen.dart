import 'package:flutter/material.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/money_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One row of the by-item breakdown.
class ItemSpend {
  final String name;
  final Money total;

  /// The exact foreign-currency figure, when the row was converted. Kept
  /// beside the converted one because it is the part that is actually true.
  final Money? foreign;

  const ItemSpend({required this.name, required this.total, this.foreign});
}

/// The link through to Savings, already worded.
class SavingsTeaser {
  /// `Cut 276,000 ₫ a year`.
  final String headline;

  /// `2 plans cost less yearly · cancelling saves more`.
  final String line;

  const SavingsTeaser({required this.headline, required this.line});
}

/// What is committed, and where it goes.
///
/// Two spans, because they answer two different questions and the wrong one is
/// misleading. **This month** is what will actually leave the account before the
/// month is out — a fact. **Next 12 months** is what the current set of
/// commitments adds up to — an estimate, and labelled as one, because a bill
/// carried twelve times forward at today's amount is a guess about the other
/// eleven.
///
/// The month breakdown is by item, not by category. Categories answer "what kind
/// of spender am I", which is a question for a budgeting app; this list answers
/// "what is taking my money", which is the one a person asks right before they
/// cancel something. The year view drops the per-item list entirely: forty
/// annualised figures answer nothing anybody asked.
class MoneyScreen extends StatelessWidget {
  final MoneyView view;

  /// Which span to offer switching to. Held by the caller so the choice
  /// survives a rebuild from new data.
  final ValueChanged<MoneySpan>? onSpan;

  final SavingsTeaser? savings;
  final VoidCallback? onOpenSavings;
  final VoidCallback? onOpenHistory;

  const MoneyScreen({
    super.key,
    required this.view,
    this.onSpan,
    this.savings,
    this.onOpenSavings,
    this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        // `Money`, while the tab that opens it says `Spending`. Not a slip:
        // the tab has to name the *act* — four verbs' worth of noun in a row
        // of five — and the screen names what is on it, which includes what is
        // not being spent. The hand-off screenshots settle it this way.
        const Text('Money', style: SubdockText.screenTitle),
        const SizedBox(height: 18),
        _TotalCard(view: view, onSpan: onSpan),
        if (savings != null) ...[
          const SizedBox(height: 12),
          _SavingsLink(teaser: savings!, onTap: onOpenSavings),
        ],
        if (view.trials.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: SubdockSpacing.sectionTop,
              bottom: SubdockSpacing.sectionBottom,
            ),
            child: Text(
              'NOT COUNTED YET · TRIALS',
              style: SubdockText.sectionLabel.copyWith(
                color: SubdockColors.accent,
              ),
            ),
          ),
          GroupedCard(
            decoration: SubdockSurface.accented(),
            children: [
              for (final trial in view.trials)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SubdockSpacing.rowH,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trial.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SubdockText.rowLink,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Starts charging ${trial.startsCharging}',
                              style: SubdockText.caption.copyWith(
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        trial.cost,
                        style: SubdockText.monoValue.copyWith(
                          color: SubdockColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (view.items.isNotEmpty) ...[
          const SectionLabel('By item'),
          GroupedCard(
            children: [
              for (final spend in view.items)
                DetailRow(
                  label: spend.name,
                  value: spend.foreign == null
                      ? MoneyFormat.full(spend.total)
                      : '≈ ${MoneyFormat.full(spend.total)}',
                  monoValue: true,
                ),
            ],
          ),
        ],
        if (onOpenHistory != null) ...[
          const SizedBox(height: 20),
          InkWell(
            onTap: onOpenHistory,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Payment history', style: SubdockText.rowLink),
                  ),
                  Text(
                    'Open ›',
                    style: TextStyle(
                      fontFamily: SubdockText.family,
                      fontSize: 15,
                      height: 1,
                      color: SubdockColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A titled block inside the total card: a rule, a heading, a sentence saying
/// how it relates to the figure above, then the rows.
///
/// The heading and the sentence are the point. Both blocks on this card are
/// *decompositions of the same total*, and stacked without labels they read as
/// three separate sums — which is exactly how a reader ends up asking where a
/// second 69 million came from.
class _CardBlock extends StatelessWidget {
  final String label;
  final String caption;
  final List<Widget> children;

  const _CardBlock({
    required this.label,
    required this.caption,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
        const SizedBox(height: 12),
        Text(label.toUpperCase(), style: SubdockText.sectionLabel),
        const SizedBox(height: 4),
        Text(caption, style: SubdockText.caption),
        const SizedBox(height: 11),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }
}

/// A label on the left, an optional figure on the right.
class _CardRow extends StatelessWidget {
  final String label;
  final String? value;

  const _CardRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final labelStyle = SubdockText.rowLabel.copyWith(fontSize: 15);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        if (value case final value?) ...[
          const SizedBox(width: 12),
          Text(value, style: SubdockText.monoValue.copyWith(fontSize: 15)),
        ],
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final MoneyView view;
  final ValueChanged<MoneySpan>? onSpan;

  const _TotalCard({required this.view, this.onSpan});

  @override
  Widget build(BuildContext context) {
    final total = view.total;
    final approximate = total.approximateBase;

    return GroupedCard(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                view.label.toUpperCase(),
                style: SubdockText.sectionLabel,
              ),
            ),
            // Sized to the wider label rather than guessed: 132 clipped
            // "Month" to "Mon…", which on a two-segment control makes the
            // unselected half unreadable.
            SizedBox(
              width: 150,
              child: SegmentedRow(
                labels: const ['Month', 'Year'],
                selected: view.span.index,
                onSelect: onSpan == null
                    ? null
                    : (i) => onSpan!(MoneySpan.values[i]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Scaled down rather than wrapped or clipped. A yearly total in dong
        // runs to nine digits, and this is the one number on the screen that
        // must never be cut off — a total missing its last digit is off by a
        // factor of ten and reads as a real figure.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            approximate == null ? '—' : '≈ ${MoneyFormat.full(approximate)}',
            style: SubdockText.figure,
          ),
        ),
        // The same total in the other currency, directly under it and quiet.
        // One number said twice, which is the whole of what a second currency
        // needs here — the per-currency subtotals that used to sit further down
        // were true and unreadable.
        if (view.alternateTotal case final alternate?) ...[
          const SizedBox(height: 4),
          Text(
            alternate,
            style: SubdockText.monoValue.copyWith(
              fontSize: 15,
              color: SubdockColors.inkSecondary,
            ),
          ),
        ],
        const SizedBox(height: 7),
        Text(view.subtitle, style: SubdockText.footnote),
        if (view.bars.isNotEmpty) ...[
          const SizedBox(height: 18),
          _BarChart(bars: view.bars),
        ],
        // A *second* breakdown of the same total, which is why it says so. Three
        // figures under a total, with nothing between them but a hairline, read
        // as more money rather than as the same money sorted.
        if (view.bands.isNotEmpty)
          _CardBlock(
            label: 'Where it goes',
            caption: 'The same total again, split by kind.',
            children: [
              for (final band in view.bands)
                _CardRow(
                  label: band.label,
                  value: '≈ ${MoneyFormat.full(band.total)}',
                ),
            ],
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: SubdockColors.hairline)),
          ),
          child: Text(
            _provenance(total.rate, total.unconvertedCount),
            style: SubdockText.caption,
          ),
        ),
      ],
    );
  }

  /// Never shows a converted figure without saying which rate produced it and
  /// when. A number with no provenance silently rewrites itself.
  String _provenance(FxRate? rate, int unconverted) {
    if (rate == null) {
      return unconverted > 0
          ? 'No usable rate — $unconverted currencies left unconverted'
          : 'One currency only, nothing to convert';
    }

    final line =
        'rate ${MoneyFormat.rate(rate)} · ${rate.source} · '
        '${MoneyFormat.date(rate.asOf)}';
    return unconverted > 0
        ? '$line · $unconverted currencies left unconverted'
        : line;
  }
}

/// Six months of what the list says each month costs.
///
/// Worked out from the items — amount, cycle, anchor — rather than from what
/// has been marked paid, so the chart stands up on a list nobody has confirmed
/// a payment on yet. The last column is the month the user is in, and it is
/// the same figure as the total above it, arrived at the same way.
///
/// Deliberately unlabelled with figures. The bars answer one question — is
/// this month unusual — and a column of nine-digit dong amounts at this width
/// would answer it worse than the shapes do. The exact figures for the current
/// month are in the list below.
///
/// Heights are relative to the tallest of the six, not to any absolute scale,
/// which is why nothing here is presented as a value to read off an axis.
class _BarChart extends StatelessWidget {
  final List<SpendBar> bars;

  /// The tallest column. Short enough that the card stays the shape the design
  /// draws it, tall enough that a half-height month is visibly half.
  static const double maxHeight = 74;

  /// What a month with nothing in it gets. Not zero: a column of no height is
  /// indistinguishable from a column that failed to draw, and the label under
  /// it would then sit beside nothing.
  static const double emptyHeight = 6;

  const _BarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final peak = bars.fold<int>(
      0,
      (best, bar) => bar.minor > best ? bar.minor : best,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COST BY MONTH', style: SubdockText.sectionLabel),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final bar in bars)
              Expanded(
                child: Semantics(
                  label: bar.minor == 0
                      ? '${bar.longLabel}: nothing due'
                      : '${bar.longLabel}: ${MoneyFormat.grouped(bar.minor)} dong',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          height: peak == 0
                              ? emptyHeight
                              : emptyHeight +
                                    (maxHeight - emptyHeight) *
                                        (bar.minor / peak),
                          decoration: BoxDecoration(
                            color: bar.current
                                ? SubdockColors.accent
                                : SubdockColors.accentSoft,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bar.label,
                          style: SubdockText.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The way through to Savings.
///
/// In the savings green rather than the accent, and outlined rather than
/// filled. It is the one row on this screen that is about money *not* going
/// out, and it has to read as a different kind of thing from the total above it
/// without becoming the loudest element on a screen whose job is the total.
class _SavingsLink extends StatelessWidget {
  final SavingsTeaser teaser;
  final VoidCallback? onTap;

  const _SavingsLink({required this.teaser, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.saving(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  size: 28,
                  color: SubdockColors.savings,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teaser.headline,
                        style: const TextStyle(
                          fontFamily: SubdockText.family,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: SubdockWeight.medium,
                          letterSpacing: -0.16,
                          color: SubdockColors.savings,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        teaser.line,
                        style: SubdockText.caption.copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '›',
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 15,
                    height: 1,
                    color: SubdockColors.savings,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
