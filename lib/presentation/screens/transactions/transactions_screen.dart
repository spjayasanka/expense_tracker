import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../actions.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../editor/transaction_editor_screen.dart';

enum GroupBy { date, category }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.title, this.initialFilter = const TxnFilter(), this.startWithSearch = false});

  final String? title;
  final TxnFilter initialFilter;
  final bool startWithSearch;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

sealed class _Item {}

class _Header extends _Item {
  _Header(this.key, this.title, this.net, this.count, this.expanded, {this.category});
  final String key;
  final String title;
  final int net;
  final int count;
  final bool expanded;
  final Category? category;
}

class _Row extends _Item {
  _Row(this.txn);
  final Txn txn;
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TxnFilter _filter = widget.initialFilter;
  late bool _searching = widget.startWithSearch;
  final _search = TextEditingController();
  GroupBy _groupBy = GroupBy.date;
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  TxnFilter get _effectiveFilter => _filter.copyWith(
        search: () => _search.text.trim().isEmpty ? null : _search.text.trim(),
      );

  List<_Item> _buildItems(List<Txn> txns, Formatters fmt, AppLocalizations l10n) {
    final conv = ref.read(converterProvider);
    final cats = ref.read(categoriesByIdProvider);
    final groups = <String, List<Txn>>{};
    final titles = <String, String>{};
    final groupCats = <String, Category?>{};
    for (final t in txns) {
      String key;
      if (_groupBy == GroupBy.date) {
        final d = dateOnly(t.date);
        key = d.toIso8601String();
        titles[key] ??= fmt.period(PeriodType.day, DateRange(d, addDays(d, 1)), l10n);
      } else {
        key = t.type == TxnType.transfer ? 'transfer' : 'cat:${t.categoryId}';
        final c = cats[t.categoryId];
        groupCats[key] = c;
        titles[key] ??= t.type == TxnType.transfer ? l10n.transfers : (c?.name ?? l10n.uncategorized);
      }
      (groups[key] ??= []).add(t);
    }
    var keys = groups.keys.toList();
    if (_groupBy == GroupBy.category) {
      int total(String k) => groups[k]!.fold(0, (s, t) => s + conv.toMain(t.amount, t.currency));
      keys.sort((a, b) => total(b).compareTo(total(a)));
    }
    final items = <_Item>[];
    for (final k in keys) {
      final list = groups[k]!;
      var net = 0;
      for (final t in list) {
        final v = conv.toMain(t.amount, t.currency);
        if (t.type == TxnType.income) net += v;
        if (t.type == TxnType.expense) net -= v;
      }
      final expanded = !_collapsed.contains(k);
      items.add(_Header(k, titles[k]!, net, list.length, expanded, category: groupCats[k]));
      if (expanded) items.addAll(list.map(_Row.new));
    }
    return items;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<TxnFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final async = ref.watch(transactionsProvider(_effectiveFilter));
    final accounts = ref.watch(accountsByIdProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final conv = ref.watch(converterProvider);
    final filterCount = (_filter.range != null ? 1 : 0) +
        (_filter.accountIds?.length ?? 0) +
        (_filter.categoryIds?.length ?? 0) +
        (_filter.types?.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(widget.title ?? l10n.transactions),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? l10n.closeSearch : l10n.search,
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.filters,
            onPressed: _openFilters,
          ),
          PopupMenuButton<GroupBy>(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: l10n.groupBy,
            initialValue: _groupBy,
            onSelected: (g) => setState(() {
              _groupBy = g;
              _collapsed.clear();
            }),
            itemBuilder: (_) => [
              PopupMenuItem(value: GroupBy.date, child: Text(l10n.groupByDate)),
              PopupMenuItem(value: GroupBy.category, child: Text(l10n.groupByCategory)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newExpense,
        onPressed: () => openTransactionEditor(context, const TransactionEditorArgs()),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.operationFailed('$e'))),
        data: (txns) {
          if (txns.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.noTransactions,
              message: (_search.text.isNotEmpty || filterCount > 0) ? l10n.noMatches : l10n.noTransactionsMessage,
            );
          }
          var income = 0, expense = 0;
          for (final t in txns) {
            if (t.type == TxnType.income) income += conv.toMain(t.amount, t.currency);
            if (t.type == TxnType.expense) expense += conv.toMain(t.amount, t.currency);
          }
          final items = _buildItems(txns, fmt, l10n);
          return Column(
            children: [
              if (_filter.range != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InputChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(fmt.range(_filter.range!)),
                    onDeleted: () => setState(() => _filter = _filter.copyWith(range: () => null)),
                    deleteButtonTooltipMessage: l10n.clearDateRange,
                  ),
                ),
              _SummaryBar(income: income, expense: expense, count: txns.length),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    switch (item) {
                      case _Header():
                        return _GroupHeader(
                          header: item,
                          onTap: () => setState(() {
                            item.expanded ? _collapsed.add(item.key) : _collapsed.remove(item.key);
                          }),
                        );
                      case _Row(:final txn):
                        return Dismissible(
                          key: ValueKey('txn-${txn.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
                          ),
                          onDismissed: (_) => deleteTransactionWithUndo(ref, txn, l10n),
                          child: TransactionTile(
                            txn: txn,
                            account: accounts[txn.accountId],
                            toAccount: txn.toAccountId == null ? null : accounts[txn.toAccountId],
                            category: txn.categoryId == null ? null : cats[txn.categoryId],
                            showDate: _groupBy == GroupBy.category,
                          ),
                        );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends ConsumerWidget {
  const _SummaryBar({required this.income, required this.expense, required this.count});
  final int income;
  final int expense;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final colors = Theme.of(context);
    Widget cell(String label, String value, Color? color) => Expanded(
          child: Column(
            children: [
              Text(label, style: colors.textTheme.labelSmall),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: colors.textTheme.titleSmall?.copyWith(color: color)),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          cell(l10n.income, fmt.main(income), txnColor(context, TxnType.income)),
          cell(l10n.expenses, fmt.main(expense), txnColor(context, TxnType.expense)),
          cell(l10n.balance, fmt.main(income - expense, signed: true), null),
          cell(l10n.count, '$count', null),
        ],
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.header, required this.onTap});
  final _Header header;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Semantics(
      button: true,
      expanded: header.expanded,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (header.category != null) ...[
                ColorIcon(icon: header.category!.icon, color: header.category!.color, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${header.title} · ${l10n.nTransactions(header.count)}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(fmt.main(header.net, signed: true), style: theme.textTheme.labelLarge),
              Icon(header.expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

/// One transaction row. Reused by reports and home lists.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.txn,
    this.account,
    this.toAccount,
    this.category,
    this.showDate = true,
  });

  final Txn txn;
  final Account? account;
  final Account? toAccount;
  final Category? category;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final isTransfer = txn.type == TxnType.transfer;
    final title = isTransfer
        ? '${account?.name ?? '?'} → ${toAccount?.name ?? '?'}'
        : (category?.name ?? l10n.uncategorized);
    final subtitle = [
      if (showDate) fmt.date(txn.date),
      if (!isTransfer && account != null) account!.name,
      if (txn.note.isNotEmpty) txn.note,
      if (txn.recurringId != null) '↻',
    ].join(' · ');
    final sign = switch (txn.type) {
      TxnType.expense => -1,
      TxnType.income => 1,
      TxnType.transfer => 0,
    };
    return ListTile(
      leading: isTransfer
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.swap_horiz, color: theme.colorScheme.onSecondaryContainer),
            )
          : ColorIcon(icon: category?.icon ?? 'category', color: category?.color ?? 0xFF757575),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        fmt.money(sign * txn.amount, txn.currency, signed: sign != 0),
        style: theme.textTheme.titleSmall?.copyWith(color: txnColor(context, txn.type)),
      ),
      onTap: () => openTransactionEditor(context, TransactionEditorArgs(existing: txn)),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final TxnFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late Set<TxnType> _types = {...?widget.initial.types};
  late Set<int> _accounts = {...?widget.initial.accountIds};
  late Set<int> _categories = {...?widget.initial.categoryIds};
  late DateRange? _range = widget.initial.range;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final accounts = ref.watch(accountsProvider);
    final cats = ref.watch(categoriesProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(l10n.filters, style: Theme.of(context).textTheme.titleLarge),
                  SectionHeader(l10n.dateRange),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_range == null ? l10n.anyDate : fmt.range(_range!)),
                    onPressed: () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1970),
                        lastDate: DateTime(2100),
                        initialDateRange: _range == null
                            ? null
                            : DateTimeRange(start: _range!.start, end: _range!.lastDay),
                      );
                      if (r != null) {
                        setState(() => _range = DateRange(dateOnly(r.start), addDays(dateOnly(r.end), 1)));
                      }
                    },
                  ),
                  SectionHeader(l10n.type),
                  Wrap(spacing: 8, children: [
                    for (final t in TxnType.values)
                      FilterChip(
                        label: Text(l10n.txnType(t)),
                        selected: _types.contains(t),
                        onSelected: (v) => setState(() => v ? _types.add(t) : _types.remove(t)),
                      ),
                  ]),
                  SectionHeader(l10n.accounts),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final a in accounts)
                      FilterChip(
                        label: Text(a.name),
                        selected: _accounts.contains(a.id),
                        onSelected: (v) => setState(() => v ? _accounts.add(a.id) : _accounts.remove(a.id)),
                      ),
                  ]),
                  SectionHeader(l10n.categories),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final c in cats)
                      FilterChip(
                        avatar: ColorIcon(icon: c.icon, color: c.color, size: 20),
                        label: Text(c.name),
                        selected: _categories.contains(c.id),
                        onSelected: (v) => setState(() => v ? _categories.add(c.id) : _categories.remove(c.id)),
                      ),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _types = {};
                      _accounts = {};
                      _categories = {};
                      _range = null;
                    }),
                    child: Text(l10n.clearAll),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TxnFilter(
                        range: _range,
                        types: _types.isEmpty ? null : _types,
                        accountIds: _accounts.isEmpty ? null : _accounts,
                        categoryIds: _categories.isEmpty ? null : _categories,
                      ),
                    ),
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
