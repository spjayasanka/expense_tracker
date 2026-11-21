import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/services/balance_calculator.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/missing_rates_banner.dart';
import '../../widgets/period_bar.dart';
import '../transactions/transactions_screen.dart';

typedef ReportQuery = ({PeriodType type, DateRange range, int? accountId});

class MonthBar {
  const MonthBar(this.range, this.income, this.expense);
  final DateRange range;
  final int income;
  final int expense;
}

class ReportData {
  const ReportData({
    required this.stats,
    required this.effectiveRange,
    required this.months,
    required this.balancePoints,
    required this.avgDailyExpense,
  });

  final PeriodStats stats;

  /// Range actually covered (all-time is narrowed to the data).
  final DateRange effectiveRange;
  final List<MonthBar> months;
  final List<(DateTime, int)> balancePoints;
  final int avgDailyExpense;
}

final reportDataProvider = FutureProvider.autoDispose.family<ReportData, ReportQuery>((ref, q) async {
  // Recompute when any transaction changes.
  ref.watch(accountFlowsProvider);
  final txRepo = ref.watch(transactionRepoProvider);
  final accRepo = ref.watch(accountRepoProvider);
  final conv = ref.watch(converterProvider);
  final settings = ref.watch(settingsProvider);
  final accounts = ref.watch(accountsProvider);
  final prefs = settings.calendar;
  final now = DateTime.now();
  final accountIds = q.accountId == null ? null : {q.accountId!};

  var range = q.range;
  if (q.type == PeriodType.all) {
    final first = await txRepo.firstDate() ?? now;
    range = DateRange(dateOnly(first), addDays(dateOnly(now), 1));
  }

  final stats = PeriodStats.fromTotals(await txRepo.categoryTotals(range, accountIds: accountIds), conv);

  // Monthly income vs expense.
  final DateRange barRange = switch (q.type) {
    PeriodType.day || PeriodType.week || PeriodType.month => DateRange(
        shiftPeriod(PeriodType.month, periodContaining(PeriodType.month, range.lastDay, prefs), -11, prefs).start,
        periodContaining(PeriodType.month, range.lastDay, prefs).end,
      ),
    _ => range,
  };
  var buckets = monthBuckets(barRange, prefs);
  if (buckets.length > 36) buckets = buckets.sublist(buckets.length - 36);
  final months = <MonthBar>[];
  for (final b in buckets) {
    final s = PeriodStats.fromTotals(await txRepo.categoryTotals(b, accountIds: accountIds), conv);
    months.add(MonthBar(b, s.income, s.expense));
  }

  // Balance over time across included accounts (or the selected account).
  final included = accounts
      .where((a) => q.accountId == null ? (a.includeInTotal && !a.isArchived) : a.id == q.accountId)
      .toList();
  final includedIds = {for (final a in included) a.id};
  const calc = BalanceCalculator();
  final before = await accRepo.flows(range: DateRange(kAllTimeStart, range.start));
  var running = 0;
  for (final a in included) {
    running += conv.toMain(calc.accountBalance(a, before[a.id] ?? AccountFlows.zero), a.currency);
  }
  final daily = await accRepo.dailyFlows(range);
  final byId = {for (final a in included) a.id: a};
  final netByDay = <DateTime, int>{};
  for (final f in daily) {
    if (!includedIds.contains(f.accountId)) continue;
    final fl = f.flows;
    final net = fl.income - fl.expense - fl.transferOut + fl.transferIn;
    netByDay[f.day] = (netByDay[f.day] ?? 0) + conv.toMain(net, byId[f.accountId]!.currency);
  }
  final lastDay = range.end.isAfter(addDays(dateOnly(now), 1)) ? dateOnly(now) : range.lastDay;
  final points = <(DateTime, int)>[];
  for (var d = range.start; !d.isAfter(lastDay); d = addDays(d, 1)) {
    running += netByDay[d] ?? 0;
    points.add((d, running));
    if (points.length > 20000) break;
  }
  // Downsample long ranges to keep the chart light.
  var sampled = points;
  if (points.length > 120) {
    final step = (points.length / 120).ceil();
    sampled = [for (var i = 0; i < points.length; i += step) points[i]];
    if (sampled.last != points.last) sampled.add(points.last);
  }

  final endForAvg = range.end.isAfter(addDays(dateOnly(now), 1)) ? addDays(dateOnly(now), 1) : range.end;
  final days = math.max(1, DateRange(range.start, endForAvg).dayCount);

  return ReportData(
    stats: stats,
    effectiveRange: range,
    months: months,
    balancePoints: sampled,
    avgDailyExpense: stats.expense ~/ days,
  );
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  PeriodType _type = PeriodType.month;
  DateRange? _custom;
  int _offset = 0;
  int? _accountId;
  CategoryType _pieType = CategoryType.expense;

  DateRange get _range {
    final prefs = ref.read(settingsProvider).calendar;
    if (_type == PeriodType.custom && _custom != null) return _custom!;
    final base = periodContaining(_type, DateTime.now(), prefs);
    return shiftPeriod(_type, base, _offset, prefs);
  }

  void _openTxns({required String title, DateRange? range, int? categoryId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          title: title,
          initialFilter: TxnFilter(
            range: range,
            accountIds: _accountId == null ? null : {_accountId!},
            categoryIds: categoryId == null ? null : {categoryId},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(settingsProvider);
    final range = _range;
    final async = ref.watch(reportDataProvider((type: _type, range: range, accountId: _accountId)));
    final accounts = ref.watch(activeAccountsProvider);
    final swipe = _type != PeriodType.all && _type != PeriodType.custom;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: l10n.chooseAccount,
            onSelected: (id) => setState(() => _accountId = id < 0 ? null : id),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: -1, checked: _accountId == null, child: Text(l10n.allAccounts)),
              for (final a in accounts)
                CheckedPopupMenuItem(value: a.id, checked: _accountId == a.id, child: Text(a.name)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const MissingRatesBanner(),
          PeriodBar(
            type: _type,
            range: range,
            onTypeChanged: (t) async {
              if (t == PeriodType.custom) {
                final r = await pickCustomRange(context, _custom);
                if (r == null) return;
                setState(() {
                  _custom = r;
                  _type = t;
                  _offset = 0;
                });
              } else {
                setState(() {
                  _type = t;
                  _offset = 0;
                });
              }
            },
            onPrevious: swipe ? () => setState(() => _offset--) : null,
            onNext: swipe ? () => setState(() => _offset++) : null,
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: swipe
                  ? (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 300) return;
                      setState(() => v < 0 ? _offset++ : _offset--);
                    }
                  : null,
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(context.l10n.operationFailed('$e'))),
                data: (data) => _ReportBody(
                  data: data,
                  pieType: _pieType,
                  onPieTypeChanged: (t) => setState(() => _pieType = t),
                  onOpen: _openTxns,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({
    required this.data,
    required this.pieType,
    required this.onPieTypeChanged,
    required this.onOpen,
  });

  final ReportData data;
  final CategoryType pieType;
  final ValueChanged<CategoryType> onPieTypeChanged;
  final void Function({required String title, DateRange? range, int? categoryId}) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final money = context.moneyColors;
    final cats = ref.watch(categoriesByIdProvider);
    final stats = data.stats;
    final byCat = pieType == CategoryType.expense ? stats.expenseByCategory : stats.incomeByCategory;
    final total = pieType == CategoryType.expense ? stats.expense : stats.income;
    final entries = byCat.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final range = data.effectiveRange;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Summary tiles.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatTile(label: l10n.income, value: fmt.main(stats.income), color: money.income),
              _StatTile(label: l10n.expenses, value: fmt.main(stats.expense), color: money.expense),
              _StatTile(label: l10n.balance, value: fmt.main(stats.balance, signed: true)),
              _StatTile(label: l10n.avgDailySpending, value: fmt.main(data.avgDailyExpense)),
            ],
          ),
        ),
        SectionHeader(
          l10n.byCategory,
          trailing: SegmentedButton<CategoryType>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: CategoryType.expense, label: Text(l10n.expenses)),
              ButtonSegment(value: CategoryType.income, label: Text(l10n.income)),
            ],
            selected: {pieType},
            onSelectionChanged: (s) => onPieTypeChanged(s.first),
          ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noDataForPeriod, textAlign: TextAlign.center),
          )
        else ...[
          SizedBox(
            height: 220,
            child: Semantics(
              label: l10n.categoryChartLabel,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value.toDouble(),
                        color: Color(cats[e.key]?.color ?? 0xFF757575),
                        radius: 52,
                        title: total == 0 || e.value / total < 0.06 ? '' : '${(e.value * 100 / total).round()}%',
                        titleStyle: theme.textTheme.labelSmall?.copyWith(
                          color: ThemeData.estimateBrightnessForColor(Color(cats[e.key]?.color ?? 0xFF757575)) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                      if (i < 0 || i >= entries.length) return;
                      final id = entries[i].key;
                      onOpen(title: cats[id]?.name ?? l10n.uncategorized, range: range, categoryId: id);
                    },
                  ),
                ),
              ),
            ),
          ),
          SectionHeader(pieType == CategoryType.expense ? l10n.topSpending : l10n.topIncome),
          for (final e in entries.take(10))
            ListTile(
              leading: ColorIcon(
                icon: cats[e.key]?.icon ?? 'category',
                color: cats[e.key]?.color ?? 0xFF757575,
                size: 36,
              ),
              title: Text(cats[e.key]?.name ?? l10n.uncategorized),
              subtitle: Text('${(total == 0 ? 0 : e.value * 100 / total).toStringAsFixed(1)}%'),
              trailing: Text(fmt.main(e.value), style: theme.textTheme.titleSmall),
              onTap: () => onOpen(title: cats[e.key]?.name ?? l10n.uncategorized, range: range, categoryId: e.key),
            ),
        ],
        SectionHeader(l10n.incomeVsExpenses),
        _MonthlyBars(
          months: data.months,
          onTap: (m) => onOpen(title: fmt.period(PeriodType.month, m.range, l10n), range: m.range),
        ),
        SectionHeader(l10n.balanceOverTime),
        _BalanceLine(points: data.balancePoints),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.sizeOf(context).width - 24 - 8) / 2;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: theme.textTheme.titleLarge?.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyBars extends ConsumerWidget {
  const _MonthlyBars({required this.months, required this.onTap});
  final List<MonthBar> months;
  final ValueChanged<MonthBar> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.fmt(context);
    final money = context.moneyColors;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (months.isEmpty) return const SizedBox(height: 40);
    final maxY = months.fold<int>(0, (m, b) => math.max(m, math.max(b.income, b.expense)));
    final barWidth = months.length > 18 ? 5.0 : 9.0;
    final width = math.max(MediaQuery.sizeOf(context).width - 16, months.length * 34.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: width,
        height: 220,
        child: Semantics(
          label: l10n.monthlyChartLabel,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= months.length) return const SizedBox();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(fmt.shortMonth(months[i].range.start), style: theme.textTheme.labelSmall),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final i = response?.spot?.touchedBarGroupIndex ?? -1;
                  if (i >= 0 && i < months.length) onTap(months[i]);
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    fmt.main(rod.toY.round(), compact: true),
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(toY: months[i].income.toDouble(), color: money.income, width: barWidth),
                      BarChartRodData(toY: months[i].expense.toDouble(), color: money.expense, width: barWidth),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceLine extends ConsumerWidget {
  const _BalanceLine({required this.points});
  final List<(DateTime, int)> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.noDataForPeriod, textAlign: TextAlign.center),
      );
    }
    final values = points.map((p) => p.$2.toDouble());
    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final pad = (maxY - minY).abs() * 0.1 + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: SizedBox(
        height: 220,
        child: Semantics(
          label: l10n.balanceChartLabel(fmt.main(points.first.$2), fmt.main(points.last.$2)),
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(fmt.main(v.round(), compact: true), style: theme.textTheme.labelSmall),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (points.length / 4).floorToDouble()),
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(fmt.dayMonth(points[i].$1), style: theme.textTheme.labelSmall),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${fmt.date(points[s.x.toInt()].$1)}\n${fmt.main(s.y.round())}',
                        TextStyle(color: theme.colorScheme.onInverseSurface),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2.toDouble())],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: theme.colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
