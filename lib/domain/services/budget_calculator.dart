import '../../core/utils/date_range.dart';
import '../entities/entities.dart';

enum BudgetAlertLevel { none, warning, exceeded }

/// Snapshot of a budget for one period.
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.range,
    required this.carriedOver,
    required this.spent,
  });

  final Budget budget;
  final DateRange range;

  /// Remaining amount rolled in from previous periods (may be negative if
  /// the previous period was overspent). Always 0 without carry-over.
  final int carriedOver;

  /// Spent in this period, main-currency minor units.
  final int spent;

  int get available => budget.amount + carriedOver;
  int get remaining => available - spent;

  /// 0.0 … >1.0 (over budget).
  double get progress {
    if (available <= 0) return spent > 0 ? double.infinity : 0;
    return spent / available;
  }

  BudgetAlertLevel get alertLevel => BudgetCalculator.levelFor(progress);
}

class BudgetCalculator {
  const BudgetCalculator();

  static const warningThreshold = 0.8;

  static BudgetAlertLevel levelFor(double progress) {
    if (progress >= 1.0) return BudgetAlertLevel.exceeded;
    if (progress >= warningThreshold) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.none;
  }

  PeriodType periodTypeOf(BudgetPeriod p) => switch (p) {
        BudgetPeriod.weekly => PeriodType.week,
        BudgetPeriod.monthly => PeriodType.month,
        BudgetPeriod.yearly => PeriodType.year,
      };

  /// The budget period containing [date].
  DateRange periodFor(Budget budget, DateTime date, CalendarPrefs prefs) =>
      periodContaining(periodTypeOf(budget.period), date, prefs);

  /// All periods from the one containing [Budget.startDate] up to and
  /// including the one containing [now], oldest first.
  List<DateRange> periodsSinceStart(Budget budget, DateTime now, CalendarPrefs prefs) {
    final type = periodTypeOf(budget.period);
    final current = periodContaining(type, now, prefs);
    var p = periodContaining(type, budget.startDate, prefs);
    if (p.start.isAfter(current.start)) return [current];
    final out = <DateRange>[];
    while (!p.start.isAfter(current.start)) {
      out.add(p);
      p = shiftPeriod(type, p, 1, prefs);
      if (out.length > 520) {
        // Hard cap (10 years of weeks) to keep work bounded.
        out.removeAt(0);
      }
    }
    return out;
  }

  /// Computes the status for the last period in [periods] given the amount
  /// spent in each period (same order, oldest first).
  ///
  /// With carry-over, whatever remained (or was overspent) in a period is
  /// added to the next period's limit.
  BudgetStatus compute({
    required Budget budget,
    required List<DateRange> periods,
    required List<int> spentPerPeriod,
  }) {
    assert(periods.length == spentPerPeriod.length && periods.isNotEmpty);
    var carry = 0;
    if (budget.carryOver) {
      for (var i = 0; i < periods.length - 1; i++) {
        final available = budget.amount + carry;
        carry = available - spentPerPeriod[i];
      }
    }
    return BudgetStatus(
      budget: budget,
      range: periods.last,
      carriedOver: carry,
      spent: spentPerPeriod.last,
    );
  }

  /// Which alert (if any) should fire now, given the highest level already
  /// notified for this period. Each level fires at most once per period.
  BudgetAlertLevel alertToSend(BudgetStatus status, BudgetAlertLevel alreadyNotified) {
    final level = status.alertLevel;
    return level.index > alreadyNotified.index ? level : BudgetAlertLevel.none;
  }
}
