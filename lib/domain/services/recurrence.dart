import '../../core/utils/date_range.dart';
import '../entities/entities.dart';

/// Pure scheduling rules for recurring transactions.
class Recurrence {
  const Recurrence();

  /// The k-th occurrence (k = 0 is [start]). Computed from the anchor rather
  /// than by repeated addition so that "monthly on the 31st" yields
  /// Jan 31, Feb 28/29, Mar 31 … instead of drifting to the 28th.
  DateTime occurrence(DateTime start, RecurrenceFrequency f, int interval, int k) {
    final step = interval < 1 ? 1 : interval;
    switch (f) {
      case RecurrenceFrequency.daily:
        return addDays(start, k * step);
      case RecurrenceFrequency.weekly:
        return addDays(start, 7 * k * step);
      case RecurrenceFrequency.monthly:
        return addMonths(start, k * step, anchorDay: start.day);
      case RecurrenceFrequency.yearly:
        return addMonths(start, 12 * k * step, anchorDay: start.day);
    }
  }

  /// First occurrence strictly after [after].
  DateTime nextAfter(RecurringRule rule, DateTime after) {
    final s = rule.startDate;
    if (s.isAfter(after)) return s;
    // Estimate k to avoid iterating over very old schedules.
    final step = rule.interval < 1 ? 1 : rule.interval;
    final days = dateOnly(after).difference(dateOnly(s)).inDays;
    int k = switch (rule.frequency) {
      RecurrenceFrequency.daily => days ~/ step,
      RecurrenceFrequency.weekly => days ~/ (7 * step),
      RecurrenceFrequency.monthly => days ~/ (31 * step),
      RecurrenceFrequency.yearly => days ~/ (366 * step),
    };
    if (k > 0) k -= 1;
    var d = occurrence(s, rule.frequency, step, k);
    while (!d.isAfter(after)) {
      k++;
      d = occurrence(s, rule.frequency, step, k);
    }
    return d;
  }

  /// Occurrences due on or before [today] (inclusive, by date), starting at
  /// [RecurringRule.nextDate], capped at [max] to stay bounded after a very
  /// long absence. Respects [RecurringRule.endDate] and pausing.
  List<DateTime> dueOccurrences(RecurringRule rule, DateTime today, {int max = 500}) {
    if (rule.isPaused) return const [];
    final limit = dateOnly(today);
    final out = <DateTime>[];
    var d = rule.nextDate;
    while (!dateOnly(d).isAfter(limit) && out.length < max) {
      if (rule.endDate != null && dateOnly(d).isAfter(dateOnly(rule.endDate!))) break;
      out.add(d);
      d = nextAfter(rule, d);
    }
    return out;
  }

  /// Whether the rule has finished (next date past its end date).
  bool isFinished(RecurringRule rule) =>
      rule.endDate != null && dateOnly(rule.nextDate).isAfter(dateOnly(rule.endDate!));

  /// Builds the transaction that an occurrence produces.
  Txn buildTxn(RecurringRule rule, DateTime date, String currency, DateTime now) {
    final t = rule.template;
    return Txn(
      id: 0,
      type: t.type,
      amount: t.amount,
      currency: currency,
      accountId: t.accountId,
      toAccountId: t.type == TxnType.transfer ? t.toAccountId : null,
      toAmount: t.type == TxnType.transfer ? t.toAmount : null,
      categoryId: t.type == TxnType.transfer ? null : t.categoryId,
      date: date,
      note: t.note,
      recurringId: rule.id,
      createdAt: now,
      updatedAt: now,
    );
  }
}
