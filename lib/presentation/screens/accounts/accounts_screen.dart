import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/services/balance_calculator.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../editor/transaction_editor_screen.dart';
import '../transactions/transactions_screen.dart';
import 'account_editor_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final balances = ref.watch(balancesProvider);
    final total = ref.watch(totalBalanceProvider);
    final missing = ref.watch(missingRatesProvider);
    final active = balances.where((b) => !b.account.isArchived).toList();
    final archived = balances.where((b) => b.account.isArchived).toList();
    final theme = Theme.of(context);

    Widget tile(AccountBalance b, {Key? key}) {
      final Account a = b.account;
      return ListTile(
        key: key,
        leading: ColorIcon(icon: a.icon, color: a.color),
        title: Text(a.name),
        subtitle: Text([
          l10n.accountType(a.type),
          a.currency,
          if (!a.includeInTotal) l10n.excludedFromTotal,
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmt.money(b.balance, a.currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: b.balance < 0 ? theme.colorScheme.error : null,
                )),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editAccount,
              onPressed: () => openAccountEditor(context, existing: a),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionsScreen(
              title: a.name,
              initialFilter: TxnFilter(accountIds: {a.id}),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.newTransfer,
            onPressed: () => openTransactionEditor(context, const TransactionEditorArgs(type: TxnType.transfer)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAccountEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newAccount),
      ),
      body: balances.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.noAccounts,
              message: l10n.noAccountsMessage,
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.allAccounts, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(fmt.main(total), style: theme.textTheme.headlineMedium),
                          if (missing.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(l10n.missingRatesWarning(missing.join(', ')),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SliverReorderableList(
                  itemCount: active.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = active.map((b) => b.account.id).toList();
                    ids.insert(newIndex, ids.removeAt(oldIndex));
                    ref.read(accountRepoProvider).reorder(ids);
                  },
                  itemBuilder: (ctx, i) => ReorderableDelayedDragStartListener(
                    key: ValueKey(active[i].account.id),
                    index: i,
                    child: Material(child: tile(active[i])),
                  ),
                ),
                if (archived.isNotEmpty) ...[
                  SliverToBoxAdapter(child: SectionHeader(l10n.archived)),
                  SliverList.list(children: [for (final b in archived) tile(b)]),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }
}
