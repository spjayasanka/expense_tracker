import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../domain/entities/entities.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../startup.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

Future<int?> openAccountEditor(BuildContext context, {Account? existing}) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => AccountEditorScreen(existing: existing)),
    );

const _typeIcons = {
  AccountType.cash: 'wallet',
  AccountType.bank: 'account_balance',
  AccountType.card: 'credit_card',
  AccountType.savings: 'savings',
  AccountType.investment: 'show_chart',
  AccountType.other: 'account_balance_wallet',
};

class AccountEditorScreen extends ConsumerStatefulWidget {
  const AccountEditorScreen({super.key, this.existing});
  final Account? existing;

  @override
  ConsumerState<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends ConsumerState<AccountEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _initial = TextEditingController();
  late AccountType _type = widget.existing?.type ?? AccountType.cash;
  late String _currency = widget.existing?.currency ?? ref.read(settingsProvider).mainCurrency;
  late String _icon = widget.existing?.icon ?? _typeIcons[_type]!;
  late int _color = widget.existing?.color ?? 0xFF43A047;
  late bool _include = widget.existing?.includeInTotal ?? true;
  late bool _archived = widget.existing?.isArchived ?? false;
  bool _iconTouched = false;
  int _txnCount = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _iconTouched = true;
      _initial.text = e.initialBalance == 0
          ? ''
          : MoneyFormatter.toEditable(e.initialBalance, currencyFor(e.currency).decimals);
      ref.read(accountRepoProvider).transactionCount(e.id).then((c) {
        if (mounted) setState(() => _txnCount = c);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final initial = _initial.text.trim().isEmpty
        ? 0
        : parseMinorUnits(_initial.text, currencyFor(_currency).decimals) ?? 0;
    final account = Account(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      type: _type,
      currency: _currency,
      initialBalance: initial,
      icon: _icon,
      color: _color,
      includeInTotal: _include,
      sortOrder: widget.existing?.sortOrder ?? 0,
      isArchived: _archived,
    );
    final repo = ref.read(accountRepoProvider);
    int id;
    if (widget.existing == null) {
      id = await repo.add(account);
      final settings = ref.read(settingsProvider);
      if (settings.defaultAccountId == null) {
        await ref.read(settingsRepoProvider).save(settings.copyWith(defaultAccountId: () => id));
      }
    } else {
      id = account.id;
      await repo.update(account);
    }
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final e = widget.existing!;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteAccountTitle(e.name),
      message: l10n.deleteAccountMessage(_txnCount),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(accountRepoProvider).delete(e.id);
    // Its recurring rules were deleted too.
    await refreshRecurringState(ref, l10n);
    final settings = ref.read(settingsProvider);
    if (settings.defaultAccountId == e.id) {
      await ref.read(settingsRepoProvider).save(settings.copyWith(defaultAccountId: () => null));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currencyLocked = widget.existing != null && _txnCount > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.newAccount : l10n.editAccount),
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
            Row(
              children: [
                Semantics(
                  button: true,
                  label: l10n.chooseIcon,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      final i = await pickIcon(context, selected: _icon, color: _color);
                      if (i != null) {
                        setState(() {
                          _icon = i;
                          _iconTouched = true;
                        });
                      }
                    },
                    child: ColorIcon(icon: _icon, color: _color, size: 56),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    key: const Key('account-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.name),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.accountTypeLabel),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(value: t, child: Text(l10n.accountType(t))),
              ],
              onChanged: (t) => setState(() {
                _type = t!;
                if (!_iconTouched) _icon = _typeIcons[t]!;
              }),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.currency_exchange),
              title: Text(l10n.currency),
              subtitle: Text(currencyLocked ? l10n.currencyLocked : currencyFor(_currency).name),
              trailing: Text(_currency, style: Theme.of(context).textTheme.titleMedium),
              enabled: !currencyLocked,
              onTap: () async {
                final c = await pickCurrency(context, selected: _currency);
                if (c != null) setState(() => _currency = c.code);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _initial,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: l10n.initialBalance,
                suffixText: _currency,
                helperText: l10n.initialBalanceHelp,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return parseMinorUnits(v, currencyFor(_currency).decimals) == null ? l10n.invalidNumber : null;
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.color),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Color(_color), shape: BoxShape.circle),
              ),
              onTap: () async {
                final c = await pickColor(context, selected: _color);
                if (c != null) setState(() => _color = c);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.includeInTotal),
              subtitle: Text(l10n.includeInTotalHelp),
              value: _include,
              onChanged: (v) => setState(() => _include = v),
            ),
            if (widget.existing != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.archived),
                subtitle: Text(l10n.archivedHelp),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('account-save'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
