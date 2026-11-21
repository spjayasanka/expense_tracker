import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../accounts/accounts_screen.dart';
import '../backup/backup_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../currencies/exchange_rates_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

enum DrawerDestination {
  home,
  transactions,
  accounts,
  categories,
  reports,
  budgets,
  recurring,
  currencies,
  backup,
  settings,
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current});
  final DrawerDestination current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    void go(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    Widget item(DrawerDestination d, IconData icon, String label, Widget Function() screen) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          selected: d == current,
          onTap: d == current ? () => Navigator.pop(context) : () => go(screen()),
        );

    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
          child: Row(
            children: [
              Icon(Icons.eco, color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                    Text(l10n.appTagline, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        item(DrawerDestination.home, Icons.donut_large, l10n.overview, () => const SizedBox()),
        item(DrawerDestination.transactions, Icons.receipt_long, l10n.transactions, () => const TransactionsScreen()),
        item(DrawerDestination.accounts, Icons.account_balance_wallet, l10n.accounts, () => const AccountsScreen()),
        item(DrawerDestination.categories, Icons.category, l10n.categories, () => const CategoriesScreen()),
        item(DrawerDestination.reports, Icons.insert_chart_outlined, l10n.reports, () => const ReportsScreen()),
        item(DrawerDestination.budgets, Icons.savings_outlined, l10n.budgets, () => const BudgetsScreen()),
        item(DrawerDestination.recurring, Icons.event_repeat, l10n.recurring, () => const RecurringScreen()),
        item(DrawerDestination.currencies, Icons.currency_exchange, l10n.exchangeRates,
            () => const ExchangeRatesScreen()),
        const Divider(),
        item(DrawerDestination.backup, Icons.backup_outlined, l10n.backupAndData, () => const BackupScreen()),
        item(DrawerDestination.settings, Icons.settings_outlined, l10n.settings, () => const SettingsScreen()),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.airplanemode_active, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.offlineBadge,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
