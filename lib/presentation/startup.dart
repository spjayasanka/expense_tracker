import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/connection.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/entities.dart';
import '../domain/usecases/recurring_generator.dart';
import 'actions.dart';
import 'l10n.dart';
import 'providers/providers.dart';
import 'screens/editor/transaction_editor_screen.dart';
import 'screens/lock/app_lock.dart';
import 'widgets/formatters.dart';

/// Recurring occurrences awaiting the user's confirmation.
class PendingRecurringController extends Notifier<List<PendingOccurrence>> {
  @override
  List<PendingOccurrence> build() => const [];

  void set(List<PendingOccurrence> items) => state = items;
  void remove(PendingOccurrence o) =>
      state = [for (final p in state) if (!(p.rule.id == o.rule.id && p.date == o.date)) p];
}

final pendingRecurringProvider =
    NotifierProvider<PendingRecurringController, List<PendingOccurrence>>(PendingRecurringController.new);

/// Call after anything that can remove or replace recurring rules (restore,
/// deleting an account/category): cancels reminders of rules that no longer
/// exist and drops pending occurrences that point at stale rule ids.
Future<void> refreshRecurringState(WidgetRef ref, AppLocalizations l10n) async {
  await syncRecurringReminders(ref, l10n);
  final result = await ref.read(recurringGeneratorProvider).run(DateTime.now());
  ref.read(pendingRecurringProvider.notifier).set(result.pending);
}

/// Runs once after the home screen appears: generates due recurring
/// transactions, takes an automatic backup if due, reschedules reminders,
/// checks budgets and keeps the home-screen widget in sync.
class StartupTasks extends ConsumerStatefulWidget {
  const StartupTasks({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<StartupTasks> createState() => _StartupTasksState();
}

class _StartupTasksState extends ConsumerState<StartupTasks> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClicks;
  DateTime? _lastRun;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    final widgets = ref.read(homeWidgetServiceProvider);
    widgets.init();
    widgets.initialLaunchUri().then(_handleUri);
    _widgetClicks = widgets.clicks.listen(_handleUri, onError: (_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back on a new day: generate anything that became due.
    if (state == AppLifecycleState.resumed) {
      final last = _lastRun;
      final now = DateTime.now();
      if (last == null || last.day != now.day || now.difference(last).inHours >= 6) _run();
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.host != 'add') return;
    final type = uri.queryParameters['type'] == 'income' ? TxnType.income : TxnType.expense;
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => TransactionEditorScreen(args: TransactionEditorArgs(type: type)),
      fullscreenDialog: true,
    ));
  }

  Future<void> _run() async {
    _lastRun = DateTime.now();
    final ctx = widget.navigatorKey.currentContext ?? context;
    final l10n = AppLocalizations.of(ctx);
    try {
      final result = await ref.read(recurringGeneratorProvider).run(DateTime.now());
      ref.read(pendingRecurringProvider.notifier).set(result.pending);
      if (result.created > 0) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(l10n.recurringCreated(result.created))),
        );
      }
    } catch (e, s) {
      debugPrint('Recurring generation failed: $e\n$s');
    }
    await _autoBackupIfDue();
    try {
      await syncRecurringReminders(ref, l10n);
      await checkBudgetAlerts(ref, l10n);
    } catch (e) {
      debugPrint('Notification sync failed: $e');
    }
  }

  Future<void> _autoBackupIfDue() async {
    final settings = ref.read(settingsProvider);
    if (settings.autoBackup == AutoBackupFrequency.off) return;
    final interval = settings.autoBackup == AutoBackupFrequency.daily
        ? const Duration(days: 1)
        : const Duration(days: 7);
    final last = settings.lastAutoBackup;
    final now = DateTime.now();
    if (last != null && now.difference(last) < interval) return;
    try {
      final dir = await autoBackupDirectory();
      await ref
          .read(backupServiceProvider)
          .autoBackup(ref.read(databaseProvider), dir, keep: settings.autoBackupKeep);
      final fresh = ref.read(settingsProvider);
      await ref.read(settingsRepoProvider).save(fresh.copyWith(lastAutoBackup: () => now));
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the home-screen widget's balance current: refresh when the total,
    // formatting settings (locale/number format/main currency) or the app
    // lock change.
    ref.listen<int>(totalBalanceProvider, (_, _) => _pushWidget());
    ref.listen(settingsProvider, (_, _) => _pushWidget());
    ref.listen<bool>(lockProvider.select((l) => l.config.enabled), (_, _) => _pushWidget());
    return widget.child;
  }

  void _pushWidget() {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    final fmt = ref.read(formattersProvider(Localizations.localeOf(ctx).toLanguageTag()));
    // With the app lock on, don't put the balance on the launcher.
    final locked = ref.read(lockProvider).config.enabled;
    ref.read(homeWidgetServiceProvider).update(
          balanceLabel: AppLocalizations.of(ctx).totalBalance,
          balance: locked ? '••••' : fmt.main(ref.read(totalBalanceProvider)),
        );
  }
}

Future<void> showPendingRecurringDialog(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _PendingSheet(),
  );
}

class _PendingSheet extends ConsumerWidget {
  const _PendingSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final pending = ref.watch(pendingRecurringProvider);
    final cats = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final gen = ref.read(recurringGeneratorProvider);
    if (pending.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.confirmRecurringTitle, style: Theme.of(context).textTheme.titleMedium),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in pending)
                    ListTile(
                      title: Text(p.rule.template.type == TxnType.transfer
                          ? l10n.transfer
                          : (cats[p.rule.template.categoryId]?.name ?? l10n.uncategorized)),
                      subtitle: Text([
                        fmt.date(p.date),
                        if (p.rule.template.note.isNotEmpty) p.rule.template.note,
                      ].join(' · ')),
                      leading: Text(
                        fmt.money(p.rule.template.amount,
                            accounts[p.rule.template.accountId]?.currency ?? ref.read(settingsProvider).mainCurrency),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: l10n.skip,
                            onPressed: () async {
                              await gen.skip(p);
                              ref.read(pendingRecurringProvider.notifier).remove(p);
                            },
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.check),
                            tooltip: l10n.confirm,
                            onPressed: () async {
                              await gen.confirm(p, DateTime.now());
                              ref.read(pendingRecurringProvider.notifier).remove(p);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
