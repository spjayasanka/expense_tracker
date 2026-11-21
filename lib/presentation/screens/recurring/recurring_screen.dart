import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../core/utils/date_range.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/services/recurrence.dart';
import '../../actions.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../startup.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/pickers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final settings = ref.watch(settingsProvider);
    final rules = ref.watch(recurringStreamProvider).value ?? const [];
    final pending = ref.watch(pendingRecurringProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    const rec = Recurrence();
    final active = rules.where((r) => !rec.isFinished(r)).toList()..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final finished = rules.where(rec.isFinished).toList();

    Widget tile(RecurringRule r) {
      final t = r.template;
      final cat = t.categoryId == null ? null : cats[t.categoryId];
      final acc = accounts[t.accountId];
      final title = t.type == TxnType.transfer
          ? '${acc?.name ?? '?'} → ${accounts[t.toAccountId]?.name ?? '?'}'
          : (t.note.isNotEmpty ? t.note : (cat?.name ?? l10n.uncategorized));
      final upcoming = [r.nextDate, rec.nextAfter(r, r.nextDate), rec.nextAfter(r, rec.nextAfter(r, r.nextDate))]
          .where((d) => r.endDate == null || !dateOnly(d).isAfter(dateOnly(r.endDate!)))
          .map(fmt.dayMonth)
          .join(', ');
      return ListTile(
        leading: t.type == TxnType.transfer
            ? const CircleAvatar(child: Icon(Icons.swap_horiz))
            : ColorIcon(icon: cat?.icon ?? 'category', color: cat?.color ?? 0xFF757575),
        title: Text(title),
        subtitle: Text([
          l10n.frequency(r.frequency, r.interval),
          if (rec.isFinished(r)) l10n.finished else if (r.isPaused) l10n.paused else l10n.nextOn(upcoming),
          if (!r.autoCreate) l10n.asksFirst,
          if (r.remindDaysBefore != null) l10n.remindsDaysBefore(r.remindDaysBefore!),
        ].join(' · ')),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmt.money(t.amount, acc?.currency ?? settings.mainCurrency),
              style: TextStyle(color: txnColor(context, t.type), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        onTap: () => openRecurringEditor(context, existing: r),
        onLongPress: () async {
          await ref.read(recurringRepoProvider).update(r.copyWith(isPaused: !r.isPaused));
          if (context.mounted) await syncRecurringReminders(ref, context.l10n);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurring)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRecurringEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newRecurring),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: Text(l10n.billReminders),
            subtitle: Text(l10n.billRemindersHelp),
            value: settings.recurringRemindersEnabled,
            onChanged: (v) async {
              if (v && !await ensureNotificationPermission(ref, context)) return;
              await ref.read(settingsRepoProvider).save(settings.copyWith(recurringRemindersEnabled: v));
              if (context.mounted) await syncRecurringReminders(ref, context.l10n);
            },
          ),
          if (pending.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.pending_actions),
                title: Text(l10n.recurringPendingBanner(pending.length)),
                trailing: TextButton(
                  onPressed: () => showPendingRecurringDialog(context, ref),
                  child: Text(l10n.review),
                ),
              ),
            ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.event_repeat,
                title: l10n.noRecurring,
                message: l10n.noRecurringMessage,
              ),
            ),
          if (active.isNotEmpty) ...[
            SectionHeader(l10n.upcoming),
            for (final r in active) tile(r),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.longPressToPause, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
          if (finished.isNotEmpty) ...[
            SectionHeader(l10n.finished),
            for (final r in finished) tile(r),
          ],
        ],
      ),
    );
  }
}

Future<void> openRecurringEditor(BuildContext context, {RecurringRule? existing}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringEditorScreen(existing: existing)),
    );

class RecurringEditorScreen extends ConsumerStatefulWidget {
  const RecurringEditorScreen({super.key, this.existing});
  final RecurringRule? existing;

  @override
  ConsumerState<RecurringEditorScreen> createState() => _RecurringEditorScreenState();
}

class _RecurringEditorScreenState extends ConsumerState<RecurringEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late TxnType _type = widget.existing?.template.type ?? TxnType.expense;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  late RecurrenceFrequency _frequency = widget.existing?.frequency ?? RecurrenceFrequency.monthly;
  late int _interval = widget.existing?.interval ?? 1;
  late DateTime _start = widget.existing?.nextDate ?? dateOnly(DateTime.now());
  late DateTime? _end = widget.existing?.endDate;
  late bool _autoCreate = widget.existing?.autoCreate ?? true;
  late bool _paused = widget.existing?.isPaused ?? false;
  late int? _remind = widget.existing?.remindDaysBefore;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final t = e.template;
      _accountId = t.accountId;
      _toAccountId = t.toAccountId;
      _categoryId = t.categoryId;
      _note.text = t.note;
      final cur = ref.read(accountsByIdProvider)[t.accountId]?.currency ?? ref.read(settingsProvider).mainCurrency;
      _amount.text = MoneyFormatter.toEditable(t.amount, currencyFor(cur).decimals);
    } else {
      _accountId = ref.read(settingsProvider).defaultAccountId ??
          ref.read(activeAccountsProvider).firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_form.currentState!.validate()) return;
    final accounts = ref.read(accountsByIdProvider);
    final account = _accountId == null ? null : accounts[_accountId];
    if (account == null) {
      showSnack(context, l10n.chooseAccount);
      return;
    }
    if (_type == TxnType.transfer && (_toAccountId == null || _toAccountId == _accountId)) {
      showSnack(context, l10n.toAccount);
      return;
    }
    if (_type != TxnType.transfer && _categoryId == null) {
      showSnack(context, l10n.chooseCategory);
      return;
    }
    final amount = parseMinorUnits(_amount.text, currencyFor(account.currency).decimals)!;
    int? toAmount;
    if (_type == TxnType.transfer) {
      final to = accounts[_toAccountId]!;
      if (to.currency != account.currency) {
        toAmount = ref.read(converterProvider).convert(amount, account.currency, to.currency);
      }
    }
    final rule = RecurringRule(
      id: widget.existing?.id ?? 0,
      template: TxnTemplate(
        type: _type,
        amount: amount,
        accountId: account.id,
        // Drop fields left over from a previous type, otherwise deleting an
        // unrelated account/category would cascade-delete this rule.
        toAccountId: _type == TxnType.transfer ? _toAccountId : null,
        toAmount: toAmount,
        categoryId: _type == TxnType.transfer ? null : _categoryId,
        note: _note.text.trim(),
      ),
      frequency: _frequency,
      interval: _interval,
      startDate: widget.existing != null && dateOnly(widget.existing!.nextDate) == dateOnly(_start)
          ? widget.existing!.startDate
          : _start,
      nextDate: _start,
      endDate: _end,
      autoCreate: _autoCreate,
      isPaused: _paused,
      remindDaysBefore: _remind,
    );
    final repo = ref.read(recurringRepoProvider);
    if (widget.existing == null) {
      await repo.add(rule);
    } else {
      await repo.update(rule);
    }
    if (_remind != null && !ref.read(settingsProvider).recurringRemindersEnabled) {
      if (mounted && await ensureNotificationPermission(ref, context)) {
        final s = ref.read(settingsProvider);
        await ref.read(settingsRepoProvider).save(s.copyWith(recurringRemindersEnabled: true));
      }
    }
    if (!mounted) return;
    await syncRecurringReminders(ref, l10n);
    // Create anything already due right away (e.g. a start date in the past).
    final result = await ref.read(recurringGeneratorProvider).run(DateTime.now());
    ref.read(pendingRecurringProvider.notifier).set(result.pending);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteRecurring,
      message: l10n.deleteRecurringMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(notificationServiceProvider).cancelReminder(widget.existing!.id);
    await ref.read(recurringRepoProvider).delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final accounts = ref.watch(accountsByIdProvider);
    final account = _accountId == null ? null : accounts[_accountId];
    final toAccount = _toAccountId == null ? null : accounts[_toAccountId];
    final cat = _categoryId == null ? null : ref.watch(categoriesByIdProvider)[_categoryId];
    final catType = _type == TxnType.income ? CategoryType.income : CategoryType.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.newRecurring : l10n.editRecurring),
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
            SegmentedButton<TxnType>(
              segments: [
                for (final t in TxnType.values) ButtonSegment(value: t, label: Text(l10n.txnType(t))),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (cat != null && cat.type != (_type == TxnType.income ? CategoryType.income : CategoryType.expense)) {
                  _categoryId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amount, suffixText: account?.currency),
              validator: (v) {
                final p = parseMinorUnits(v ?? '', currencyFor(account?.currency ?? 'USD').decimals);
                return p == null || p <= 0 ? l10n.enterAmount : null;
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: account == null ? const Icon(Icons.account_balance_wallet) : ColorIcon(icon: account.icon, color: account.color),
              title: Text(account?.name ?? l10n.chooseAccount),
              subtitle: Text(_type == TxnType.transfer ? l10n.fromAccount : l10n.account),
              onTap: () async {
                final a = await pickAccount(context, selectedId: _accountId);
                if (a != null) setState(() => _accountId = a.id);
              },
            ),
            if (_type == TxnType.transfer)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: toAccount == null ? const Icon(Icons.arrow_forward) : ColorIcon(icon: toAccount.icon, color: toAccount.color),
                title: Text(toAccount?.name ?? l10n.toAccount),
                subtitle: Text(l10n.toAccount),
                onTap: () async {
                  final a = await pickAccount(context, selectedId: _toAccountId, excludeId: _accountId);
                  if (a != null) setState(() => _toAccountId = a.id);
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: cat == null ? const Icon(Icons.category_outlined) : ColorIcon(icon: cat.icon, color: cat.color),
                title: Text(cat?.name ?? l10n.chooseCategory),
                subtitle: Text(l10n.category),
                onTap: () async {
                  final c = await pickCategory(context, type: catType, selectedId: _categoryId);
                  if (c != null) setState(() => _categoryId = c.id);
                },
              ),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.noteOptional),
            ),
            SectionHeader(l10n.schedule),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: '$_interval',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.every),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 999 ? l10n.invalidNumber : null;
                    },
                    onChanged: (v) => setState(() => _interval = int.tryParse(v) ?? _interval),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RecurrenceFrequency>(
                    initialValue: _frequency,
                    decoration: InputDecoration(labelText: l10n.frequencyLabel),
                    items: [
                      for (final f in RecurrenceFrequency.values)
                        DropdownMenuItem(value: f, child: Text(l10n.frequencyName(f))),
                    ],
                    onChanged: (f) => setState(() => _frequency = f!),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(widget.existing == null ? l10n.startDate : l10n.nextDate),
              trailing: Text(fmt.date(_start)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(1970),
                  lastDate: DateTime(2100),
                );
                if (d != null) {
                  setState(() {
                    _start = d;
                    // An end date before the new start would make the rule finished already.
                    if (_end != null && _end!.isBefore(d)) _end = null;
                  });
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: Text(l10n.endDate),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_end == null ? l10n.never : fmt.date(_end!)),
                  if (_end != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.clear,
                      onPressed: () => setState(() => _end = null),
                    ),
                ],
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _end == null || _end!.isBefore(_start) ? _start : _end!,
                  firstDate: _start,
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _end = d);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.autoCreate),
              subtitle: Text(_autoCreate ? l10n.autoCreateOnHelp : l10n.autoCreateOffHelp),
              value: _autoCreate,
              onChanged: (v) => setState(() => _autoCreate = v),
            ),
            DropdownButtonFormField<int>(
              initialValue: _remind ?? -1,
              decoration: InputDecoration(labelText: l10n.reminder, prefixIcon: const Icon(Icons.alarm)),
              items: [
                DropdownMenuItem(value: -1, child: Text(l10n.noReminder)),
                for (final d in const [0, 1, 2, 3, 7])
                  DropdownMenuItem(value: d, child: Text(d == 0 ? l10n.onTheDay : l10n.daysBefore(d))),
              ],
              onChanged: (v) => setState(() => _remind = (v == null || v < 0) ? null : v),
            ),
            if (widget.existing != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.paused),
                value: _paused,
                onChanged: (v) => setState(() => _paused = v),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
