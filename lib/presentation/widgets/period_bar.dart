import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_range.dart';
import '../l10n.dart';
import 'formatters.dart';

Future<DateRange?> pickCustomRange(BuildContext context, DateRange? current) async {
  final now = DateTime.now();
  final r = await showDateRangePicker(
    context: context,
    firstDate: DateTime(1970),
    lastDate: DateTime(2100),
    initialDateRange: current == null
        ? DateTimeRange(start: addDays(dateOnly(now), -29), end: dateOnly(now))
        : DateTimeRange(start: current.start, end: current.lastDay),
  );
  if (r == null) return null;
  return DateRange(dateOnly(r.start), addDays(dateOnly(r.end), 1));
}

/// Day / Week / Month / Year / All / Custom selector with prev/next arrows.
class PeriodBar extends ConsumerWidget {
  const PeriodBar({
    super.key,
    required this.type,
    required this.range,
    required this.onTypeChanged,
    this.onPrevious,
    this.onNext,
  });

  final PeriodType type;
  final DateRange range;
  final ValueChanged<PeriodType> onTypeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    String label(PeriodType t) => switch (t) {
          PeriodType.day => l10n.periodDay,
          PeriodType.week => l10n.periodWeek,
          PeriodType.month => l10n.periodMonth,
          PeriodType.year => l10n.periodYear,
          PeriodType.all => l10n.periodAll,
          PeriodType.custom => l10n.periodCustom,
        };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final t in PeriodType.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    key: Key('period-${t.name}'),
                    label: Text(label(t)),
                    selected: t == type,
                    // Custom can be re-picked while already selected.
                    onSelected: (_) => onTypeChanged(t),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.previousPeriod,
              onPressed: onPrevious,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  fmt.period(type, range, l10n),
                  key: const Key('period-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.nextPeriod,
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}
