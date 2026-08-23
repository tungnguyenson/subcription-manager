import 'package:flutter/material.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/money_format.dart';
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

/// What is committed this month, and where it goes.
///
/// The breakdown is by item, not by category. Categories answer "what kind of
/// spender am I", which is a question for a budgeting app; this list answers
/// "what is taking my money", which is the one a person asks right before they
/// cancel something.
class MoneyScreen extends StatelessWidget {
  final MixedTotal thisMonth;
  final List<ItemSpend> items;

  const MoneyScreen({
    super.key,
    required this.thisMonth,
    this.items = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        const Text('Money', style: SubdockText.screenTitle),
        const SizedBox(height: 18),
        _ThisMonthCard(total: thisMonth, itemCount: items.length),
        if (items.isNotEmpty) ...[
          const SectionLabel('By item'),
          GroupedCard(
            children: [
              for (final spend in items)
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
      ],
    );
  }
}

class _ThisMonthCard extends StatelessWidget {
  final MixedTotal total;
  final int itemCount;

  const _ThisMonthCard({required this.total, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final approximate = total.approximateBase;

    return GroupedCard(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('THIS MONTH', style: SubdockText.sectionLabel),
        const SizedBox(height: 10),
        Text(
          approximate == null ? '—' : '≈ ${MoneyFormat.full(approximate)}',
          style: SubdockText.figure,
        ),
        const SizedBox(height: 7),
        Text(
          '$itemCount ${itemCount == 1 ? "item" : "items"}',
          style: SubdockText.itemSubtitle.copyWith(fontSize: 12),
        ),
        if (total.perCurrency.length > 1) ...[
          const SizedBox(height: 7),
          // The exact per-currency subtotals sit directly under the
          // approximation, because they are the part that is actually true.
          Text(
            total.perCurrency.values.map(MoneyFormat.full).join(' · '),
            style: SubdockText.monoValue,
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: SubdockColors.hairline)),
          ),
          child: Text(
            _provenance(total.rate, total.unconvertedCount),
            style: SubdockText.footnote,
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
        'rate ${MoneyFormat.rate(rate)} · ${rate.source} · ${MoneyFormat.date(rate.asOf)}';
    return unconverted > 0
        ? '$line · $unconverted currencies left unconverted'
        : line;
  }
}
