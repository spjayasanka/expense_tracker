import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/services/budget_calculator.dart';
import '../../actions.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/pickers.dart';
import '../transactions/transactions_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(budgetStatusesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgets)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openBudgetEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newBudget),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.operationFailed('$e'))),
        data: (statuses) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.budgetAlerts),
              subtitle: Text(l10n.budgetAlertsHelp),
              value: settings.budgetAlertsEnabled,
              onChanged: (v) async {
                if (v && !await ensureNotificationPermission(ref, context)) return;
                await ref.read(settingsRepoProvider).save(settings.copyWith(budgetAlertsEnabled: v));
              },
            ),
            const Divider(),
            if (statuses.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.savings_outlined,
                  title: l10n.noBudgets,
                  message: l10n.noBudgetsMessage,
                ),
              )
            else
              for (final s in (statuses.toList()
                ..sort((a, b) => (a.budget.isOverall ? 0 : 1).compareTo(b.budget.isOverall ? 0 : 1))))
                _BudgetCard(status: s),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.status});
  final BudgetStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final theme = Theme.of(context);
    final cat = status.budget.categoryId == null ? null : ref.watch(categoriesByIdProvider)[status.budget.categoryId];
    final name = status.budget.isOverall ? l10n.overallBudget : (cat?.name ?? l10n.budget);
    final progress = status.progress.isFinite ? status.progress : 1.0;
    final color = switch (status.alertLevel) {
      BudgetAlertLevel.none => theme.colorScheme.primary,
      BudgetAlertLevel.warning => const Color(0xFFE08A00),
      BudgetAlertLevel.exceeded => context.moneyColors.expense,
    };
    final pct = (progress * 100).round();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openBudgetEditor(context, existing: status.budget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (cat != null)
                    ColorIcon(icon: cat.icon, color: cat.color, size: 32)
                  else
                    Icon(Icons.savings, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        Text(
                          '${l10n.budgetPeriod(status.budget.period)} · ${fmt.range(status.range)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.list),
                    tooltip: l10n.transactions,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsScreen(
                          title: name,
                          initialFilter: TxnFilter(
                            range: status.range,
                            types: const {TxnType.expense},
                            categoryIds: status.budget.categoryId == null ? null : {status.budget.categoryId!},
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  semanticsLabel: name,
                  semanticsValue: '$pct%',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.spentOf(fmt.main(status.spent), fmt.main(status.available)),
                        style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    status.remaining >= 0
                        ? l10n.remainingAmount(fmt.main(status.remaining))
                        : l10n.overBy(fmt.main(-status.remaining)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: status.remaining >= 0 ? null : context.moneyColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (status.budget.carryOver && status.carriedOver != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.carriedOver(fmt.main(status.carriedOver, signed: true)),
                      style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openBudgetEditor(BuildContext context, {Budget? existing}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BudgetEditorScreen(existing: existing)),
    );

class BudgetEditorScreen extends ConsumerStatefulWidget {
  const BudgetEditorScreen({super.key, this.existing});
  final Budget? existing;

  @override
  ConsumerState<BudgetEditorScreen> createState() => _BudgetEditorScreenState();
}

class _BudgetEditorScreenState extends ConsumerState<BudgetEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController();
  late int? _categoryId = widget.existing?.categoryId;
  late BudgetPeriod _period = widget.existing?.period ?? BudgetPeriod.monthly;
  late bool _carryOver = widget.existing?.carryOver ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = MoneyFormatter.toEditable(e.amount, _decimals);
    }
  }

  int get _decimals => currencyFor(ref.read(settingsProvider).mainCurrency).decimals;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _saving = true;
    try {
      await _doSave();
    } finally {
      _saving = false;
    }
  }

  Future<void> _doSave() async {
    final amount = parseMinorUnits(_amount.text, _decimals)!;
    final repo = ref.read(budgetRepoProvider);
    final existingSame = (await repo.getAll()).where((b) =>
        b.id != widget.existing?.id && b.categoryId == _categoryId && b.period == _period);
    if (existingSame.isNotEmpty) {
      if (mounted) showSnack(context, context.l10n.budgetExists);
      return;
    }
    final prefs = ref.read(settingsProvider).calendar;
    final budget = Budget(
      id: widget.existing?.id ?? 0,
      categoryId: _categoryId,
      amount: amount,
      period: _period,
      carryOver: _carryOver,
      startDate: widget.existing?.startDate ??
          periodContaining(const BudgetCalculator().periodTypeOf(_period), DateTime.now(), prefs).start,
    );
    if (widget.existing == null) {
      await repo.add(budget);
    } else {
      await repo.update(budget);
    }
    if (mounted) {
      await checkBudgetAlerts(ref, context.l10n);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteBudget,
      message: l10n.deleteBudgetMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(budgetRepoProvider).delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cat = _categoryId == null ? null : ref.watch(categoriesByIdProvider)[_categoryId];
    final main = ref.watch(settingsProvider).mainCurrency;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.newBudget : l10n.editBudget),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.overallBudget)),
                ButtonSegment(value: false, label: Text(l10n.categoryBudget)),
              ],
              selected: {_categoryId == null},
              onSelectionChanged: (s) async {
                if (s.first) {
                  setState(() => _categoryId = null);
                } else {
                  final c = await pickCategory(context, type: CategoryType.expense);
                  if (c != null) setState(() => _categoryId = c.id);
                }
              },
            ),
            if (_categoryId != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: cat == null ? null : ColorIcon(icon: cat.icon, color: cat.color),
                title: Text(cat?.name ?? l10n.chooseCategory),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final c = await pickCategory(context, type: CategoryType.expense, selectedId: _categoryId);
                  if (c != null) setState(() => _categoryId = c.id);
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.budgetLimit, suffixText: main),
              validator: (v) {
                final p = parseMinorUnits(v ?? '', _decimals);
                return p == null || p <= 0 ? l10n.enterAmount : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BudgetPeriod>(
              initialValue: _period,
              decoration: InputDecoration(labelText: l10n.period),
              items: [
                for (final p in BudgetPeriod.values) DropdownMenuItem(value: p, child: Text(l10n.budgetPeriod(p))),
              ],
              onChanged: (p) => setState(() => _period = p!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.carryOver),
              subtitle: Text(l10n.carryOverHelp),
              value: _carryOver,
              onChanged: (v) => setState(() => _carryOver = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
