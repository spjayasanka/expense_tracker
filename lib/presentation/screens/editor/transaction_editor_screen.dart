import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../core/utils/calculator.dart';
import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/recurrence.dart';
import '../../actions.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/calculator_keypad.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/pickers.dart';
import '../accounts/account_editor_screen.dart';

class TransactionEditorArgs {
  const TransactionEditorArgs({
    this.type = TxnType.expense,
    this.categoryId,
    this.accountId,
    this.existing,
  });

  final TxnType type;
  final int? categoryId;
  final int? accountId;
  final Txn? existing;
}

Future<bool?> openTransactionEditor(BuildContext context, TransactionEditorArgs args) =>
    Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TransactionEditorScreen(args: args), fullscreenDialog: true),
    );

class TransactionEditorScreen extends ConsumerStatefulWidget {
  const TransactionEditorScreen({super.key, required this.args});
  final TransactionEditorArgs args;

  @override
  ConsumerState<TransactionEditorScreen> createState() => _TransactionEditorScreenState();
}

class _TransactionEditorScreenState extends ConsumerState<TransactionEditorScreen> {
  late TxnType _type;
  CalculatorState _calc = const CalculatorState.empty();
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  late DateTime _date;
  final _note = TextEditingController();
  final _toAmount = TextEditingController();
  bool _toAmountEdited = false;
  RecurrenceFrequency? _repeat;
  bool _saving = false;

  Txn? get _existing => widget.args.existing;
  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    _type = e?.type ?? widget.args.type;
    _categoryId = e?.categoryId ?? widget.args.categoryId;
    _accountId = e?.accountId ?? widget.args.accountId;
    _toAccountId = e?.toAccountId;
    _date = e?.date ?? DateTime.now();
    _note.text = e?.note ?? '';
    if (e != null) {
      _calc = CalculatorState.fromMinor(e.amount, currencyFor(e.currency).decimals);
      if (e.toAmount != null) {
        _toAmountEdited = true;
        final toCurrency = ref.read(accountsByIdProvider)[e.toAccountId]?.currency ?? e.currency;
        _toAmount.text = MoneyFormatter.toEditable(e.toAmount!, currencyFor(toCurrency).decimals);
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _toAmount.dispose();
    super.dispose();
  }

  Account? _resolveAccount(List<Account> active, Map<int, Account> byId) {
    if (_accountId != null && byId.containsKey(_accountId)) return byId[_accountId];
    final settings = ref.read(settingsProvider);
    final def = settings.defaultAccountId;
    final a = (def != null ? byId[def] : null) ?? (active.isNotEmpty ? active.first : null);
    return a?.isArchived == true ? (active.isNotEmpty ? active.first : null) : a;
  }

  void _resetToAmount() {
    _toAmountEdited = false;
    _toAmount.clear();
  }

  int _decimals(Account? a) => currencyFor(a?.currency ?? ref.read(settingsProvider).mainCurrency).decimals;

  Future<void> _save(Account? account) async {
    final l10n = context.l10n;
    if (_saving) return;
    if (account == null) {
      showSnack(context, l10n.createAccountFirst);
      return;
    }
    final amount = _calc.evaluate(_decimals(account));
    if (amount == null || amount <= 0) {
      showSnack(context, l10n.enterAmount);
      return;
    }
    final byId = ref.read(accountsByIdProvider);
    int? toAmount;
    if (_type == TxnType.transfer) {
      final to = _toAccountId == null ? null : byId[_toAccountId];
      if (to == null || to.id == account.id) {
        final picked = await pickAccount(context, excludeId: account.id, title: l10n.toAccount);
        if (picked == null) return;
        setState(() => _toAccountId = picked.id);
        return _save(account);
      }
      if (to.currency != account.currency) {
        toAmount = _toAmountEdited
            ? parseMinorUnits(_toAmount.text, currencyFor(to.currency).decimals)
            : ref.read(converterProvider).convert(amount, account.currency, to.currency);
        if (toAmount == null || toAmount <= 0) {
          showSnack(context, l10n.enterReceivedAmount);
          return;
        }
      }
    } else if (_categoryId == null ||
        ref.read(categoriesByIdProvider)[_categoryId]?.type != _categoryTypeFor(_type)) {
      final picked = await pickCategory(context, type: _categoryTypeFor(_type));
      if (picked == null || !mounted) return;
      setState(() => _categoryId = picked.id);
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final repo = ref.read(transactionRepoProvider);
      var txn = Txn(
        id: _existing?.id ?? 0,
        type: _type,
        amount: amount,
        currency: account.currency,
        accountId: account.id,
        toAccountId: _type == TxnType.transfer ? _toAccountId : null,
        toAmount: toAmount,
        categoryId: _type == TxnType.transfer ? null : _categoryId,
        date: _date,
        note: _note.text.trim(),
        recurringId: _existing?.recurringId,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
      if (!_isEdit && _repeat != null) {
        const rec = Recurrence();
        final draft = RecurringRule(
          id: 0,
          template: TxnTemplate(
            type: txn.type,
            amount: txn.amount,
            accountId: txn.accountId,
            toAccountId: txn.toAccountId,
            toAmount: txn.toAmount,
            categoryId: txn.categoryId,
            note: txn.note,
          ),
          frequency: _repeat!,
          startDate: dateOnly(_date),
          nextDate: dateOnly(_date),
        );
        final next = rec.nextAfter(draft, dateOnly(_date));
        final ruleId = await ref.read(recurringRepoProvider).add(draft.copyWith(nextDate: next));
        txn = txn.copyWith(recurringId: () => ruleId);
      }
      if (_isEdit) {
        await repo.update(txn);
      } else {
        await repo.add(txn);
      }
      if (_repeat != null) await syncRecurringReminders(ref, l10n);
      if (txn.type == TxnType.expense) await checkBudgetAlerts(ref, l10n);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static CategoryType _categoryTypeFor(TxnType t) =>
      t == TxnType.income ? CategoryType.income : CategoryType.expense;

  Future<void> _delete() async {
    final e = _existing;
    if (e == null) return;
    Navigator.of(context).pop(false);
    await deleteTransactionWithUndo(ref, e, context.l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fmt = ref.fmt(context);
    final active = ref.watch(activeAccountsProvider);
    final byId = ref.watch(accountsByIdProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final account = _resolveAccount(active, byId);
    final toAccount = _toAccountId == null ? null : byId[_toAccountId];
    final category = _categoryId == null ? null : cats[_categoryId];
    final decimals = _decimals(account);
    final currency = account?.currency ?? ref.watch(settingsProvider).mainCurrency;
    final color = txnColor(context, _type);
    final result = _calc.evaluate(decimals);
    final crossCurrency =
        _type == TxnType.transfer && toAccount != null && account != null && toAccount.currency != account.currency;

    final title = _isEdit
        ? l10n.editTransaction
        : switch (_type) {
            TxnType.expense => l10n.newExpense,
            TxnType.income => l10n.newIncome,
            TxnType.transfer => l10n.newTransfer,
          };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.close,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  SegmentedButton<TxnType>(
                    segments: [
                      ButtonSegment(value: TxnType.expense, label: Text(l10n.expense), icon: const Icon(Icons.remove)),
                      ButtonSegment(value: TxnType.income, label: Text(l10n.income), icon: const Icon(Icons.add)),
                      ButtonSegment(
                          value: TxnType.transfer, label: Text(l10n.transfer), icon: const Icon(Icons.swap_horiz)),
                    ],
                    selected: {_type},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() {
                      _type = s.first;
                      if (category != null && category.type != _categoryTypeFor(_type)) _categoryId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    label: l10n.amount,
                    value: result == null ? _calc.display : fmt.money(result, currency),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_calc.display} ${currencyFor(currency).symbol}',
                              key: const Key('amount-display'),
                              style: theme.textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                              maxLines: 1,
                            ),
                          ),
                          if (_calc.hasOperator)
                            Text(
                              result == null ? '—' : '= ${fmt.money(result, currency)}',
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: account == null
                            ? const Icon(Icons.account_balance_wallet_outlined)
                            : ColorIcon(icon: account.icon, color: account.color, size: 24),
                        label: Text(account?.name ?? l10n.chooseAccount),
                        tooltip: _type == TxnType.transfer ? l10n.fromAccount : l10n.account,
                        onPressed: () async {
                          if (active.isEmpty) {
                            await openAccountEditor(context);
                            return;
                          }
                          final a = await pickAccount(context, selectedId: account?.id);
                          if (a == null) return;
                          setState(() {
                            if (a.currency != account?.currency) _resetToAmount();
                            _accountId = a.id;
                          });
                        },
                      ),
                      if (_type == TxnType.transfer)
                        ActionChip(
                          avatar: toAccount == null
                              ? const Icon(Icons.arrow_forward)
                              : ColorIcon(icon: toAccount.icon, color: toAccount.color, size: 24),
                          label: Text(toAccount?.name ?? l10n.toAccount),
                          tooltip: l10n.toAccount,
                          onPressed: () async {
                            final a = await pickAccount(context,
                                selectedId: _toAccountId, excludeId: account?.id, title: l10n.toAccount);
                            if (a == null) return;
                            setState(() {
                              // A received amount typed for another currency is meaningless now.
                              if (a.currency != toAccount?.currency) _resetToAmount();
                              _toAccountId = a.id;
                            });
                          },
                        )
                      else
                        ActionChip(
                          key: const Key('category-chip'),
                          avatar: category == null
                              ? const Icon(Icons.category_outlined)
                              : ColorIcon(icon: category.icon, color: category.color, size: 24),
                          label: Text(category?.name ?? l10n.chooseCategory),
                          tooltip: l10n.category,
                          onPressed: () async {
                            final c = await pickCategory(context,
                                type: _categoryTypeFor(_type), selectedId: _categoryId);
                            if (c != null) setState(() => _categoryId = c.id);
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.event),
                        label: Text(fmt.date(_date)),
                        tooltip: l10n.date,
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1970),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) {
                            setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
                          }
                        },
                      ),
                      if (!_isEdit)
                        _RepeatChip(value: _repeat, onChanged: (v) => setState(() => _repeat = v)),
                    ],
                  ),
                  if (crossCurrency) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _toAmount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.receivedAmount(toAccount.currency),
                        hintText: result == null
                            ? null
                            : MoneyFormatter.toEditable(
                                ref.read(converterProvider).convert(result, account.currency, toAccount.currency),
                                currencyFor(toAccount.currency).decimals),
                        helperText: l10n.receivedAmountHelp,
                      ),
                      onChanged: (_) => _toAmountEdited = _toAmount.text.trim().isNotEmpty,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l10n.noteOptional,
                      prefixIcon: const Icon(Icons.notes),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            CalculatorKeypad(
              decimalsAllowed: decimals > 0,
              showEquals: _calc.hasOperator,
              onDigit: (d) => setState(() => _calc = _calc.inputDigit(d, maxDecimals: decimals)),
              onDecimal: () => setState(() => _calc = _calc.inputDecimal(maxDecimals: decimals)),
              onOperator: (o) => setState(() => _calc = _calc.inputOperator(o)),
              onBackspace: () => setState(() => _calc = _calc.backspace()),
              onClear: () => setState(() => _calc = _calc.clear()),
              onEquals: () => setState(() => _calc = _calc.equals(decimals)),
              onSave: _saving ? null : () => _save(account),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({required this.value, required this.onChanged});
  final RecurrenceFrequency? value;
  final ValueChanged<RecurrenceFrequency?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // -1 means "does not repeat" (a null popup value would count as cancel).
    return PopupMenuButton<int>(
      tooltip: l10n.repeat,
      onSelected: (i) => onChanged(i < 0 ? null : RecurrenceFrequency.values[i]),
      itemBuilder: (_) => [
        PopupMenuItem(value: -1, child: Text(l10n.doesNotRepeat)),
        for (final f in RecurrenceFrequency.values)
          PopupMenuItem(value: f.index, child: Text(l10n.frequencyName(f))),
      ],
      child: Chip(
        avatar: const Icon(Icons.repeat),
        label: Text(value == null ? l10n.repeat : l10n.frequencyName(value!)),
      ),
    );
  }
}
