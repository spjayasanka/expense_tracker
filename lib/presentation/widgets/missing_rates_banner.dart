import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../providers/providers.dart';
import '../screens/currencies/exchange_rates_screen.dart';

/// Warns that some account currencies have no exchange rate, so totals in the
/// main currency are using 1:1. Tapping opens the exchange rates screen.
/// Renders nothing when every rate is present.
class MissingRatesBanner extends ConsumerWidget {
  const MissingRatesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingRatesProvider);
    if (missing.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExchangeRatesScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.currency_exchange, size: 20, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.missingRatesWarning((missing.toList()..sort()).join(', ')),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
