import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../domain/entities/entities.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/pickers.dart';

/// Changes the main currency and rebases every stored rate so totals keep
/// their meaning. Returns false if rates had to be cleared.
Future<bool> changeMainCurrency(WidgetRef ref, String newMain) async {
  final settings = ref.read(settingsProvider);
  final oldMain = settings.mainCurrency;
  if (oldMain == newMain) return true;
  final repo = ref.read(rateRepoProvider);
  final budgetRepo = ref.read(budgetRepoProvider);
  final settingsRepo = ref.read(settingsRepoProvider);
  final rates = {for (final r in await repo.getAll()) r.currencyCode: r.rateToMain};
  final pivot = rates[newMain];
  final now = DateTime.now();
  var kept = true;
  // One transaction so a crash midway can't leave rates half-rebased.
  await ref.read(databaseProvider).transaction(() async {
    await repo.clear();
    if (pivot != null && pivot > 0) {
      for (final e in rates.entries) {
        if (e.key == newMain) continue;
        await repo.upsert(ExchangeRate(currencyCode: e.key, rateToMain: e.value / pivot, updatedAt: now));
      }
      await repo.upsert(ExchangeRate(currencyCode: oldMain, rateToMain: 1 / pivot, updatedAt: now));
    } else {
      kept = rates.isEmpty;
    }
    // Budgets are stored in minor units of the main currency, so convert
    // them too (e.g. $500.00 → ¥75,000 rather than ¥50,000).
    final oldDec = currencyFor(oldMain).decimals;
    final newDec = currencyFor(newMain).decimals;
    if ((pivot != null && pivot > 0) || oldDec != newDec) {
      final factor = (pivot != null && pivot > 0 ? 1 / pivot : 1.0) * _pow10(newDec) / _pow10(oldDec);
      for (final b in await budgetRepo.getAll()) {
        await budgetRepo.update(b.copyWith(amount: (b.amount * factor).round()));
      }
    }
    await settingsRepo.save(settings.copyWith(mainCurrency: newMain));
  });
  return kept;
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

class ExchangeRatesScreen extends ConsumerWidget {
  const ExchangeRatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final settings = ref.watch(settingsProvider);
    final main = settings.mainCurrency;
    final rates = ref.watch(ratesStreamProvider).value ?? const [];
    final byCode = {for (final r in rates) r.currencyCode: r};
    final used = ref.watch(accountsProvider).map((a) => a.currency).toSet();
    final codes = {...used, ...byCode.keys}..remove(main);
    final sorted = codes.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exchangeRates)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addRate),
        onPressed: () async {
          final c = await pickCurrency(context);
          if (c != null && c.code != main && context.mounted) {
            await editRateDialog(context, ref, c.code);
          }
        },
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(l10n.mainCurrency),
            subtitle: Text(currencyFor(main).name),
            trailing: Text(main, style: Theme.of(context).textTheme.titleMedium),
            onTap: () async {
              final c = await pickCurrency(context, selected: main);
              if (c == null || !context.mounted) return;
              final kept = await changeMainCurrency(ref, c.code);
              if (!kept && context.mounted) showSnack(context, l10n.ratesCleared);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l10n.ratesOfflineNote, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Divider(),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(icon: Icons.currency_exchange, title: l10n.noRatesNeeded),
            ),
          for (final code in sorted)
            ListTile(
              leading: CircleAvatar(child: Text(currencyFor(code).symbol, maxLines: 1)),
              title: Text('1 $code = ${byCode[code] == null ? '?' : _fmtRate(byCode[code]!.rateToMain)} $main'),
              subtitle: Text(byCode[code] == null
                  ? l10n.rateMissing
                  : l10n.rateUpdated(fmt.date(byCode[code]!.updatedAt))),
              trailing: byCode[code] == null
                  ? Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, semanticLabel: l10n.rateMissing)
                  : (used.contains(code)
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.delete,
                          onPressed: () => ref.read(rateRepoProvider).delete(code),
                        )),
              onTap: () => editRateDialog(context, ref, code),
            ),
        ],
      ),
    );
  }
}

String _fmtRate(double r) {
  final s = r.toStringAsPrecision(8);
  if (!s.contains('.') || s.contains('e')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

Future<void> editRateDialog(BuildContext context, WidgetRef ref, String code) async {
  final l10n = context.l10n;
  final main = ref.read(settingsProvider).mainCurrency;
  final existing = ref.read(converterProvider).rateFor(code);
  final controller = TextEditingController(text: existing == null ? '' : _fmtRate(existing));
  final inverse = TextEditingController(text: existing == null || existing == 0 ? '' : _fmtRate(1 / existing));
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.exchangeRateFor(code)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: '1 $code = ', suffixText: main),
            onChanged: (v) {
              final d = double.tryParse(v.replaceAll(',', '.'));
              inverse.text = d == null || d == 0 ? '' : _fmtRate(1 / d);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: inverse,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: '1 $main = ', suffixText: code),
            onChanged: (v) {
              final d = double.tryParse(v.replaceAll(',', '.'));
              controller.text = d == null || d == 0 ? '' : _fmtRate(1 / d);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final d = double.tryParse(controller.text.replaceAll(',', '.'));
            if (d == null || d <= 0 || !d.isFinite) return;
            Navigator.pop(ctx, d);
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  // Controllers are left to GC: the dialog's fields may still be animating out.
  if (value != null) {
    await ref
        .read(rateRepoProvider)
        .upsert(ExchangeRate(currencyCode: code, rateToMain: value, updatedAt: DateTime.now()));
  }
}
