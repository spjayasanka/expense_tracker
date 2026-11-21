import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../startup.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/missing_rates_banner.dart';
import '../../widgets/period_bar.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pickers.dart';
import '../accounts/account_editor_screen.dart';
import '../accounts/accounts_screen.dart';
import '../editor/transaction_editor_screen.dart';
import '../transactions/transactions_screen.dart';
import 'app_drawer.dart';

const _kCenterPage = 10000;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pages = PageController(initialPage: _kCenterPage);
  int _offset = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _resetOffset() {
    _offset = 0;
    if (_pages.hasClients) _pages.jumpToPage(_kCenterPage);
  }

  DateRange _rangeFor(int offset) {
    final period = ref.read(homePeriodProvider);
    final prefs = ref.read(settingsProvider).calendar;
    final base = basePeriodRange(period, prefs, DateTime.now());
    return period.swipeable ? shiftPeriod(period.type, base, offset, prefs) : base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = ref.watch(homePeriodProvider);
    ref.watch(settingsProvider); // rebuild on calendar prefs change
    final accounts = ref.watch(activeAccountsProvider);
    final byId = ref.watch(accountsByIdProvider);
    final selected = period.accountId == null ? null : byId[period.accountId];
    // The PageView is rebuilt at the current period when the account changes,
    // so the offset (period label, list range) must follow.
    ref.listen(homePeriodProvider.select((p) => p.accountId), (prev, next) {
      if (prev != next) setState(_resetOffset);
    });
    // Selected account was deleted: fall back to "All accounts".
    if (period.accountId != null && selected == null && byId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(homePeriodProvider.notifier).setAccount(null);
      });
    }
    final pending = ref.watch(pendingRecurringProvider);
    final range = _rangeFor(_offset);

    return Scaffold(
      drawer: const AppDrawer(current: DrawerDestination.home),
      appBar: AppBar(
        title: _AccountSelector(selected: selected, accounts: accounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen(startWithSearch: true)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: l10n.transactions,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionsScreen(
                  title: ref.read(formattersProvider(Localizations.localeOf(context).toLanguageTag()))
                      .period(period.type, range, l10n),
                  initialFilter: TxnFilter(
                    range: period.type == PeriodType.all ? null : range,
                    accountIds: period.accountId == null ? null : {period.accountId!},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const MissingRatesBanner(),
            if (pending.isNotEmpty)
              MaterialBanner(
                leading: const Icon(Icons.event_repeat),
                content: Text(l10n.recurringPendingBanner(pending.length)),
                actions: [
                  TextButton(
                    onPressed: () => showPendingRecurringDialog(context, ref),
                    child: Text(l10n.review),
                  ),
                ],
              ),
            PeriodBar(
              type: period.type,
              range: range,
              onTypeChanged: (t) async {
                if (t == PeriodType.custom) {
                  final r = await pickCustomRange(context, period.custom);
                  if (r == null) return;
                  ref.read(homePeriodProvider.notifier).setCustom(r);
                } else {
                  ref.read(homePeriodProvider.notifier).setType(t);
                }
                setState(_resetOffset);
              },
              onPrevious: period.swipeable
                  ? () => _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                  : null,
              onNext: period.swipeable
                  ? () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                  : null,
            ),
            Expanded(
              child: accounts.isEmpty
                  ? EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: l10n.noAccounts,
                      message: l10n.noAccountsMessage,
                      action: FilledButton.icon(
                        onPressed: () => openAccountEditor(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.newAccount),
                      ),
                    )
                  : PageView.builder(
                      key: ValueKey('${period.type}-${period.custom}-${period.accountId}'),
                      controller: _pages,
                      itemCount: period.swipeable ? null : 1,
                      physics: period.swipeable ? null : const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _offset = period.swipeable ? i - _kCenterPage : 0),
                      itemBuilder: (ctx, i) {
                        final r = period.swipeable ? _rangeFor(i - _kCenterPage) : _rangeFor(0);
                        return _PeriodPage(range: r, accountId: period.accountId, periodType: period.type);
                      },
                    ),
            ),
            _BottomBar(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _AccountSelector extends ConsumerWidget {
  const _AccountSelector({required this.selected, required this.accounts});
  final Account? selected;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<int>(
      tooltip: l10n.chooseAccount,
      onSelected: (id) => ref.read(homePeriodProvider.notifier).setAccount(id < 0 ? null : id),
      itemBuilder: (_) => [
        PopupMenuItem(value: -1, child: Text(l10n.allAccounts)),
        for (final a in accounts)
          PopupMenuItem(
            value: a.id,
            child: Row(children: [
              ColorIcon(icon: a.icon, color: a.color, size: 24),
              const SizedBox(width: 12),
              Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(selected?.name ?? l10n.allAccounts, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _PeriodPage extends ConsumerWidget {
  const _PeriodPage({required this.range, required this.accountId, required this.periodType});
  final DateRange range;
  final int? accountId;
  final PeriodType periodType;

  void _openList(BuildContext context, WidgetRef ref, {int? categoryId, String? title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          title: title,
          initialFilter: TxnFilter(
            range: periodType == PeriodType.all ? null : range,
            accountIds: accountId == null ? null : {accountId!},
            categoryIds: categoryId == null ? null : {categoryId},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final stats = ref.watch(periodStatsProvider((range: range, accountId: accountId))).value ?? PeriodStats.empty;
    final allCats = ref.watch(categoriesProvider);
    final catsById = ref.watch(categoriesByIdProvider);
    final expenseCats = allCats.where((c) => c.type == CategoryType.expense && !c.isHidden).toList();

    final breakdown = stats.expenseByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, math.max(280.0, constraints.maxHeight - 8));
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: side,
            child: Center(
              child: SizedBox.square(
                dimension: side,
                child: _DonutWithBubbles(
                  side: side,
                  stats: stats,
                  categories: expenseCats,
                  catsById: catsById,
                  onCategoryTap: (c) => openTransactionEditor(
                    context,
                    TransactionEditorArgs(type: TxnType.expense, categoryId: c.id, accountId: accountId),
                  ),
                  onMore: () async {
                    final c = await pickCategory(context, type: CategoryType.expense);
                    if (c != null && context.mounted) {
                      openTransactionEditor(
                        context,
                        TransactionEditorArgs(type: TxnType.expense, categoryId: c.id, accountId: accountId),
                      );
                    }
                  },
                  onSegmentTap: (catId) =>
                      _openList(context, ref, categoryId: catId, title: catsById[catId]?.name),
                  onCenterTap: () => _openList(context, ref, title: fmt.period(periodType, range, l10n)),
                ),
              ),
            ),
          ),
          if (breakdown.isNotEmpty) ...[
            SectionHeader(l10n.expensesByCategory),
            for (final e in breakdown)
              ListTile(
                dense: true,
                leading: ColorIcon(
                  icon: catsById[e.key]?.icon ?? 'category',
                  color: catsById[e.key]?.color ?? 0xFF757575,
                  size: 32,
                ),
                title: Text(catsById[e.key]?.name ?? l10n.uncategorized),
                subtitle: LinearProgressIndicator(
                  value: stats.expense == 0 ? 0 : e.value / stats.expense,
                  color: Color(catsById[e.key]?.color ?? 0xFF757575),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  semanticsLabel: catsById[e.key]?.name,
                  semanticsValue: '${(stats.expense == 0 ? 0 : e.value * 100 / stats.expense).round()}%',
                ),
                trailing: Text(fmt.main(e.value)),
                onTap: () => _openList(context, ref, categoryId: e.key, title: catsById[e.key]?.name),
              ),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}

class _DonutWithBubbles extends ConsumerWidget {
  const _DonutWithBubbles({
    required this.side,
    required this.stats,
    required this.categories,
    required this.catsById,
    required this.onCategoryTap,
    required this.onMore,
    required this.onSegmentTap,
    required this.onCenterTap,
  });

  final double side;
  final PeriodStats stats;
  final List<Category> categories;
  final Map<int, Category> catsById;
  final ValueChanged<Category> onCategoryTap;
  final VoidCallback onMore;
  final ValueChanged<int?> onSegmentTap;
  final VoidCallback onCenterTap;

  static const _maxBubbles = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final money = context.moneyColors;

    final bubble = (side * 0.13).clamp(40.0, 60.0);
    final ringRadius = side / 2 - bubble / 2 - 4;
    final outer = ringRadius - bubble / 2 - 10;
    final inner = outer * 0.68;

    final showMore = categories.length > _maxBubbles;
    final shown = showMore ? categories.take(_maxBubbles - 1).toList() : categories;
    final slots = shown.length + (showMore ? 1 : 0);

    final entries = stats.expenseByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final ca = catsById[a.key]?.sortOrder ?? 9999;
        final cb = catsById[b.key]?.sortOrder ?? 9999;
        return ca.compareTo(cb);
      });
    final sections = entries.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: theme.colorScheme.surfaceContainerHighest,
              radius: outer - inner,
              showTitle: false,
            ),
          ]
        : [
            for (final e in entries)
              PieChartSectionData(
                value: e.value.toDouble(),
                color: Color(catsById[e.key]?.color ?? 0xFF757575),
                radius: outer - inner,
                showTitle: false,
              ),
          ];

    Offset pos(int i) {
      final angle = -math.pi / 2 + 2 * math.pi * i / math.max(slots, 1);
      return Offset(side / 2 + ringRadius * math.cos(angle), side / 2 + ringRadius * math.sin(angle));
    }

    Widget positioned(int i, Widget child) {
      final p = pos(i);
      return Positioned(left: p.dx - bubble / 2, top: p.dy - bubble / 2, width: bubble, height: bubble, child: child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: SizedBox.square(
              dimension: outer * 2,
              child: Semantics(
                label: l10n.expensesChartLabel,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: inner,
                    sectionsSpace: entries.length > 1 ? 2 : 0,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent || entries.isEmpty) return;
                        final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (idx >= 0 && idx < entries.length) onSegmentTap(entries[idx].key);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: SizedBox.square(
              dimension: inner * 1.6,
              child: Semantics(
                button: true,
                label: l10n.periodSummaryLabel(
                  fmt.main(stats.income),
                  fmt.main(stats.expense),
                  fmt.main(stats.balance),
                ),
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCenterTap,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmt.main(stats.income),
                              key: const Key('home-income'),
                              style: theme.textTheme.titleMedium?.copyWith(color: money.income)),
                          const SizedBox(height: 2),
                          Text(fmt.main(stats.expense),
                              key: const Key('home-expense'),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: money.expense, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(l10n.balance, style: theme.textTheme.labelSmall),
                          Text(fmt.main(stats.balance, signed: true), style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < shown.length; i++)
          positioned(
            i,
            _CategoryBubble(
              category: shown[i],
              size: bubble,
              spent: stats.expenseByCategory[shown[i].id] ?? 0,
              onTap: () => onCategoryTap(shown[i]),
            ),
          ),
        if (showMore)
          positioned(
            shown.length,
            Tooltip(
              message: l10n.moreCategories,
              child: Material(
                shape: const CircleBorder(),
                color: theme.colorScheme.surfaceContainerHighest,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onMore,
                  child: const Center(child: Icon(Icons.more_horiz)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryBubble extends ConsumerWidget {
  const _CategoryBubble({required this.category, required this.size, required this.spent, required this.onTap});
  final Category category;
  final double size;
  final int spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final label = l10n.addExpenseIn(category.name, fmt.main(spent));
    return Tooltip(
      message: '${category.name} · ${fmt.main(spent)}',
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: Key('category-bubble-${category.id}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Opacity(
            opacity: spent > 0 ? 1 : 0.85,
            child: ColorIcon(icon: category.icon, color: category.color, size: size),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.selected});
  final Account? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final money = context.moneyColors;
    final balances = ref.watch(balancesProvider);
    final String balanceText;
    if (selected == null) {
      balanceText = fmt.main(ref.watch(totalBalanceProvider));
    } else {
      final b = balances.where((b) => b.account.id == selected!.id).firstOrNull;
      balanceText = fmt.money(b?.balance ?? 0, selected!.currency);
    }
    final accountId = selected?.id;

    Widget bigButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, Key? key}) =>
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: SizedBox(
            width: 72,
            height: 72,
            child: FilledButton(
              key: key,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              onPressed: onTap,
              child: Icon(icon, size: 40),
            ),
          ),
        );

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            bigButton(
              key: const Key('home-add-expense'),
              label: l10n.addExpense,
              icon: Icons.remove,
              color: money.expense,
              onTap: () => openTransactionEditor(context, TransactionEditorArgs(type: TxnType.expense, accountId: accountId)),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(selected == null ? l10n.totalBalance : l10n.accountBalance,
                          style: theme.textTheme.labelMedium),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(balanceText,
                            key: const Key('home-balance'),
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bigButton(
              key: const Key('home-add-income'),
              label: l10n.addIncome,
              icon: Icons.add,
              color: money.income,
              onTap: () => openTransactionEditor(context, TransactionEditorArgs(type: TxnType.income, accountId: accountId)),
            ),
          ],
        ),
      ),
    );
  }
}
