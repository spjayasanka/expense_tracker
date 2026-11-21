import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currencies.dart';
import '../../../core/money/money_format.dart';
import '../../../domain/entities/app_settings.dart';
import '../../actions.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pickers.dart';
import '../backup/backup_screen.dart';
import '../currencies/exchange_rates_screen.dart';
import '../lock/app_lock.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final repo = ref.read(settingsRepoProvider);
    final lock = ref.watch(lockProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sampleDate = DateTime(DateTime.now().year, 12, 31);

    Future<void> save(AppSettings next) => repo.save(next);

    String weekday(int d) => DateFormat.EEEE(locale).format(DateTime(2024, 1, d)); // 2024-01-01 is Monday

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(l10n.appearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.theme),
            trailing: DropdownButton<AppThemeMode>(
              value: s.themeMode,
              onChanged: (v) => save(s.copyWith(themeMode: v)),
              items: [
                DropdownMenuItem(value: AppThemeMode.system, child: Text(l10n.themeSystem)),
                DropdownMenuItem(value: AppThemeMode.light, child: Text(l10n.themeLight)),
                DropdownMenuItem(value: AppThemeMode.dark, child: Text(l10n.themeDark)),
              ],
            ),
          ),
          SectionHeader(l10n.regional),
          ListTile(
            leading: SizedBox(
              width: 24,
              child: FittedBox(
                child: Text(
                  currencyFor(s.mainCurrency).symbol,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: IconTheme.of(context).color,
                  ),
                ),
              ),
            ),
            title: Text(l10n.mainCurrency),
            subtitle: Text('${s.mainCurrency} – ${currencyFor(s.mainCurrency).name}'),
            onTap: () async {
              final c = await pickCurrency(context, selected: s.mainCurrency);
              if (c == null || !context.mounted) return;
              final kept = await changeMainCurrency(ref, c.code);
              if (!kept && context.mounted) showSnack(context, l10n.ratesCleared);
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(l10n.exchangeRates),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExchangeRatesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.view_week_outlined),
            title: Text(l10n.firstDayOfWeek),
            trailing: DropdownButton<int>(
              value: s.firstDayOfWeek,
              onChanged: (v) => save(s.copyWith(firstDayOfWeek: v)),
              items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekday(d)))],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l10n.monthStartDay),
            subtitle: Text(l10n.monthStartDayHelp),
            trailing: DropdownButton<int>(
              value: s.monthStartDay,
              onChanged: (v) => save(s.copyWith(monthStartDay: v)),
              items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d'))],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l10n.numberFormat),
            trailing: DropdownButton<NumberFormatStyle>(
              value: s.numberFormat,
              onChanged: (v) => save(s.copyWith(numberFormat: v)),
              items: [
                for (final f in NumberFormatStyle.values)
                  DropdownMenuItem(value: f, child: Text(MoneyFormatter(style: f).formatNumber(123456789, 2))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.dateFormat),
            trailing: DropdownButton<String>(
              value: s.dateFormat,
              onChanged: (v) => save(s.copyWith(dateFormat: v)),
              items: [
                for (final f in kDateFormats)
                  DropdownMenuItem(value: f, child: Text(DateFormat(f, locale).format(sampleDate))),
              ],
            ),
          ),
          SectionHeader(l10n.notifications),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.budgetAlerts),
            subtitle: Text(l10n.budgetAlertsHelp),
            value: s.budgetAlertsEnabled,
            onChanged: (v) async {
              if (v && !await ensureNotificationPermission(ref, context)) return;
              await save(s.copyWith(budgetAlertsEnabled: v));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: Text(l10n.billReminders),
            subtitle: Text(l10n.billRemindersHelp),
            value: s.recurringRemindersEnabled,
            onChanged: (v) async {
              if (v && !await ensureNotificationPermission(ref, context)) return;
              await save(s.copyWith(recurringRemindersEnabled: v));
              if (context.mounted) await syncRecurringReminders(ref, context.l10n);
            },
          ),
          SectionHeader(l10n.security),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(l10n.appLock),
            subtitle: Text(l10n.appLockHelp),
            value: lock.config.enabled,
            onChanged: (v) async {
              if (v) {
                final ok = await confirmDialog(
                  context,
                  title: l10n.appLock,
                  message: l10n.pinWarning,
                  confirmLabel: l10n.iUnderstand,
                );
                if (!ok || !context.mounted) return;
                final pin = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                );
                if (pin != null) await ref.read(lockProvider.notifier).enableWithPin(pin);
              } else {
                // Require the current PIN before turning the lock off.
                if (!await confirmCurrentPin(context, ref)) return;
                await ref.read(lockProvider.notifier).disable();
              }
            },
          ),
          if (lock.config.enabled) ...[
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(l10n.changePin),
              onTap: () async {
                if (!await confirmCurrentPin(context, ref) || !context.mounted) return;
                final pin = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                );
                if (pin != null) {
                  await ref.read(lockProvider.notifier).enableWithPin(pin);
                  if (context.mounted) showSnack(context, l10n.pinChanged);
                }
              },
            ),
            FutureBuilder<bool>(
              future: ref.read(appLockServiceProvider).biometricsAvailable(),
              builder: (ctx, snap) => SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l10n.biometricUnlock),
                subtitle: Text(snap.data == false ? l10n.biometricsUnavailable : l10n.biometricUnlockHelp),
                value: lock.config.biometrics,
                onChanged: snap.data == true ? (v) => ref.read(lockProvider.notifier).setBiometrics(v) : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.autoLock),
              trailing: DropdownButton<int>(
                value: const [0, 30, 60, 300, 900].contains(lock.config.autoLockSeconds)
                    ? lock.config.autoLockSeconds
                    : 30,
                onChanged: (v) => ref.read(lockProvider.notifier).setAutoLock(v!),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.immediately)),
                  DropdownMenuItem(value: 30, child: Text(l10n.afterSeconds(30))),
                  DropdownMenuItem(value: 60, child: Text(l10n.afterMinutes(1))),
                  DropdownMenuItem(value: 300, child: Text(l10n.afterMinutes(5))),
                  DropdownMenuItem(value: 900, child: Text(l10n.afterMinutes(15))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.pinWarning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          ],
          SectionHeader(l10n.data),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupAndData),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          SectionHeader(l10n.about),
          ListTile(
            leading: const Icon(Icons.eco_outlined),
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.aboutText),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacy),
            subtitle: Text(l10n.privacyText),
          ),
        ],
      ),
    );
  }
}
