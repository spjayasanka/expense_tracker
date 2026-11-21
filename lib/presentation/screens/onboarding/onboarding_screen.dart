import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../domain/entities/entities.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';

/// First launch: three intro pages (skippable), then currency + first
/// account. No sign-up, no permissions.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _setup = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_setup) return const _SetupScreen();
    final theme = Theme.of(context);
    final intro = [
      (Icons.touch_app_outlined, l10n.introQuickTitle, l10n.introQuickBody),
      (Icons.account_balance_wallet_outlined, l10n.introAccountsTitle, l10n.introAccountsBody),
      (Icons.shield_outlined, l10n.introBackupTitle, l10n.introBackupBody),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('onboarding-skip'),
                onPressed: () => setState(() => _setup = true),
                child: Text(l10n.skip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, title, body) in intro)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          CircleAvatar(
                            radius: 64,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(icon, size: 64, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 32),
                          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Semantics(
              label: l10n.pageIndicator(_page + 1, intro.length),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < intro.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: () {
                    if (_page < intro.length - 1) {
                      _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    } else {
                      setState(() => _setup = true);
                    }
                  },
                  child: Text(_page < intro.length - 1 ? l10n.next : l10n.getStarted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupScreen extends ConsumerStatefulWidget {
  const _SetupScreen();

  @override
  ConsumerState<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<_SetupScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController();
  final _balance = TextEditingController();
  String _currency = _guessCurrency();
  AccountType _type = AccountType.cash;
  bool _saving = false;

  static String _guessCurrency() {
    // Offline guess from the device locale's region; falls back to USD.
    final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? '';
    const map = {
      'US': 'USD', 'GB': 'GBP', 'IN': 'INR', 'JP': 'JPY', 'CN': 'CNY', 'CA': 'CAD', 'AU': 'AUD',
      'NZ': 'NZD', 'CH': 'CHF', 'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK', 'PL': 'PLN', 'CZ': 'CZK',
      'HU': 'HUF', 'RO': 'RON', 'BR': 'BRL', 'MX': 'MXN', 'AR': 'ARS', 'CL': 'CLP', 'CO': 'COP',
      'PE': 'PEN', 'ZA': 'ZAR', 'NG': 'NGN', 'KE': 'KES', 'EG': 'EGP', 'TR': 'TRY', 'RU': 'RUB',
      'UA': 'UAH', 'KR': 'KRW', 'SG': 'SGD', 'MY': 'MYR', 'ID': 'IDR', 'TH': 'THB', 'VN': 'VND',
      'PH': 'PHP', 'PK': 'PKR', 'BD': 'BDT', 'LK': 'LKR', 'NP': 'NPR', 'AE': 'AED', 'SA': 'SAR',
      'IL': 'ILS', 'HK': 'HKD', 'TW': 'TWD',
      'DE': 'EUR', 'FR': 'EUR', 'ES': 'EUR', 'IT': 'EUR', 'NL': 'EUR', 'BE': 'EUR', 'AT': 'EUR',
      'IE': 'EUR', 'PT': 'EUR', 'FI': 'EUR', 'GR': 'EUR', 'SK': 'EUR', 'SI': 'EUR', 'LT': 'EUR',
      'LV': 'EUR', 'EE': 'EUR', 'LU': 'EUR', 'MT': 'EUR', 'CY': 'EUR', 'HR': 'EUR',
    };
    return map[region] ?? 'USD';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) _name.text = context.l10n.defaultAccountName;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await _createAccountAndFinish();
    } catch (e) {
      // Re-enable the button so the user can retry instead of being stuck.
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, context.l10n.operationFailed('$e'));
      }
    }
  }

  Future<void> _createAccountAndFinish() async {
    final dec = currencyFor(_currency).decimals;
    final initial = _balance.text.trim().isEmpty ? 0 : parseMinorUnits(_balance.text, dec) ?? 0;
    final id = await ref.read(accountRepoProvider).add(Account(
          id: 0,
          name: _name.text.trim(),
          type: _type,
          currency: _currency,
          initialBalance: initial,
          icon: _type == AccountType.bank ? 'account_balance' : (_type == AccountType.card ? 'credit_card' : 'wallet'),
          color: 0xFF2E7D32,
        ));
    final settings = await ref.read(settingsRepoProvider).get();
    await ref.read(settingsRepoProvider).save(settings.copyWith(
          mainCurrency: _currency,
          defaultAccountId: () => id,
          onboardingDone: true,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cur = currencyFor(_currency);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.setupIntro, style: theme.textTheme.bodyLarge),
            SectionHeader(l10n.mainCurrency),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const Key('setup-currency'),
                leading: CircleAvatar(child: Text(cur.symbol, maxLines: 1)),
                title: Text(cur.code),
                subtitle: Text(cur.name),
                trailing: const Icon(Icons.expand_more),
                onTap: () async {
                  final c = await pickCurrency(context, selected: _currency);
                  if (c != null) setState(() => _currency = c.code);
                },
              ),
            ),
            SectionHeader(l10n.firstAccount),
            TextFormField(
              key: const Key('setup-account-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.accountName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.accountTypeLabel),
              items: [
                for (final t in AccountType.values) DropdownMenuItem(value: t, child: Text(l10n.accountType(t))),
              ],
              onChanged: (t) => setState(() => _type = t!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: l10n.currentBalance,
                suffixText: _currency,
                helperText: l10n.initialBalanceHelp,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return parseMinorUnits(v, cur.decimals) == null ? l10n.invalidNumber : null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              key: const Key('setup-finish'),
              onPressed: _saving ? null : _finish,
              icon: const Icon(Icons.check),
              label: Text(l10n.startUsing),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.airplanemode_active, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.offlineBadge, style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
