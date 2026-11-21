import '../../core/utils/date_range.dart';
import '../entities/entities.dart';
import '../repositories/repositories.dart';
import '../services/budget_calculator.dart';
import '../services/currency_converter.dart';

/// Computes budget progress and decides when 80 % / 100 % alerts fire.
class BudgetService {
  BudgetService({
    required this.budgets,
    required this.transactions,
    required this.settings,
    this.calculator = const BudgetCalculator(),
  });

  final BudgetRepository budgets;
  final TransactionRepository transactions;
  final SettingsRepository settings;
  final BudgetCalculator calculator;

  Future<BudgetStatus> statusFor(
    Budget budget,
    DateTime now,
    CalendarPrefs prefs,
    CurrencyConverter converter,
  ) async {
    final periods = budget.carryOver
        ? calculator.periodsSinceStart(budget, now, prefs)
        : [calculator.periodFor(budget, now, prefs)];
    final spent = <int>[];
    for (final p in periods) {
      final byCurrency = await transactions.expenseByCurrency(p, categoryId: budget.categoryId);
      spent.add(converter.sumToMain(byCurrency));
    }
    return calculator.compute(budget: budget, periods: periods, spentPerPeriod: spent);
  }

  Future<List<BudgetStatus>> allStatuses(
    DateTime now,
    CalendarPrefs prefs,
    CurrencyConverter converter,
  ) async {
    final list = await budgets.getAll();
    return [for (final b in list) await statusFor(b, now, prefs, converter)];
  }

  static String _alertKey(BudgetStatus s) =>
      'budgetAlert:${s.budget.id}:${s.range.start.toIso8601String()}';

  /// Returns the alerts that should be shown now and records them so each
  /// threshold fires at most once per budget period.
  Future<List<(BudgetStatus, BudgetAlertLevel)>> pendingAlerts(
    DateTime now,
    CalendarPrefs prefs,
    CurrencyConverter converter,
  ) async {
    final out = <(BudgetStatus, BudgetAlertLevel)>[];
    for (final s in await allStatuses(now, prefs, converter)) {
      final key = _alertKey(s);
      final stored = await settings.getValue(key);
      final already = BudgetAlertLevel.values
              .where((l) => l.name == stored)
              .firstOrNull ??
          BudgetAlertLevel.none;
      final level = calculator.alertToSend(s, already);
      if (level != BudgetAlertLevel.none) {
        await settings.setValue(key, level.name);
        out.add((s, level));
      }
    }
    return out;
  }
}
