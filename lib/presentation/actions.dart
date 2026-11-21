import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/notification_service.dart';
import '../domain/entities/entities.dart';
import '../domain/services/budget_calculator.dart';
import 'l10n.dart';
import 'providers/providers.dart';

/// App-wide messenger so snackbars survive route pops (e.g. undo after
/// deleting from the editor).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> deleteTransactionWithUndo(WidgetRef ref, Txn txn, AppLocalizations l10n) async {
  final repo = ref.read(transactionRepoProvider);
  final deleted = await repo.delete(txn.id);
  if (deleted == null) return;
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.transactionDeleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: l10n.undo, onPressed: () => repo.restore(deleted)),
      ),
    );
}

/// Shows local notifications for budgets that crossed 80 % / 100 %.
Future<void> checkBudgetAlerts(WidgetRef ref, AppLocalizations l10n) async {
  final settings = ref.read(settingsProvider);
  if (!settings.budgetAlertsEnabled) return;
  final alerts = await ref
      .read(budgetServiceProvider)
      .pendingAlerts(DateTime.now(), settings.calendar, ref.read(converterProvider));
  if (alerts.isEmpty) return;
  final cats = ref.read(categoriesByIdProvider);
  final money = settings.money;
  final notifications = ref.read(notificationServiceProvider);
  for (final (status, level) in alerts) {
    final name = status.budget.categoryId == null
        ? l10n.overallBudget
        : cats[status.budget.categoryId]?.name ?? l10n.budget;
    final title = level == BudgetAlertLevel.exceeded
        ? l10n.budgetExceededTitle(name)
        : l10n.budgetWarningTitle(name);
    final body = l10n.budgetAlertBody(
      money.format(status.spent, settings.mainCurrency),
      money.format(status.available, settings.mainCurrency),
    );
    await notifications.showBudgetAlert(budgetId: status.budget.id, title: title, body: body);
  }
}

/// (Re)schedules "bill due" reminders for every recurring rule.
Future<void> syncRecurringReminders(WidgetRef ref, AppLocalizations l10n) async {
  final settings = ref.read(settingsProvider);
  final notifications = ref.read(notificationServiceProvider);
  final rules = await ref.read(recurringRepoProvider).getAll();
  final cats = ref.read(categoriesByIdProvider);
  final accounts = ref.read(accountsByIdProvider);
  await notifications.cancelRemindersExcept({for (final r in rules) r.id});
  for (final r in rules) {
    await notifications.cancelReminder(r.id);
    if (!settings.recurringRemindersEnabled || r.isPaused || r.remindDaysBefore == null) continue;
    final due = r.nextDate;
    // Rule has finished: no more bills to remind about.
    if (r.endDate != null && due.isAfter(r.endDate!)) continue;
    final when = DateTime(due.year, due.month, due.day - r.remindDaysBefore!, 9);
    final t = r.template;
    final name = t.type == TxnType.transfer
        ? l10n.transfer
        : (t.note.isNotEmpty ? t.note : cats[t.categoryId]?.name ?? l10n.recurring);
    final currency = accounts[t.accountId]?.currency ?? settings.mainCurrency;
    await notifications.scheduleReminder(
      ruleId: r.id,
      when: when,
      title: l10n.reminderTitle(name),
      body: l10n.reminderBody(settings.money.format(t.amount, currency), r.remindDaysBefore!),
    );
  }
}

/// Requests notification permission the first time a feature needs it.
Future<bool> ensureNotificationPermission(WidgetRef ref, BuildContext context) async {
  final granted = await ref.read(notificationServiceProvider).requestPermission();
  if (!granted && context.mounted) {
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(context.l10n.notificationPermissionDenied)),
    );
  }
  return granted;
}

int reminderIdFor(int ruleId) => NotificationService.reminderId(ruleId);
