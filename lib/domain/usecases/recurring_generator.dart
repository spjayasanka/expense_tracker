import '../entities/entities.dart';
import '../repositories/repositories.dart';
import '../services/recurrence.dart';

/// An occurrence that is due but waits for the user's confirmation.
class PendingOccurrence {
  const PendingOccurrence(this.rule, this.date);
  final RecurringRule rule;
  final DateTime date;
}

class GenerationResult {
  const GenerationResult({required this.created, required this.pending});

  /// Number of transactions created automatically.
  final int created;

  /// Due occurrences of rules that ask for confirmation first.
  final List<PendingOccurrence> pending;
}

/// Generates transactions for recurring rules that became due, e.g. while
/// the app was closed. Runs entirely on-device at app start.
class RecurringGenerator {
  RecurringGenerator({
    required this.recurring,
    required this.transactions,
    required this.accounts,
    this.recurrence = const Recurrence(),
  });

  final RecurringRepository recurring;
  final TransactionRepository transactions;
  final AccountRepository accounts;
  final Recurrence recurrence;

  /// Shared across instances so overlapping callers (startup + the
  /// recurring screen) can't both generate the same occurrences.
  static Future<GenerationResult>? _inFlight;

  Future<GenerationResult> run(DateTime now) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final f = _run(now);
    _inFlight = f;
    return f.whenComplete(() => _inFlight = null);
  }

  Future<GenerationResult> _run(DateTime now) async {
    var created = 0;
    final pending = <PendingOccurrence>[];
    final rules = await recurring.getAll();
    for (final rule in rules) {
      if (rule.isPaused) continue;
      final due = recurrence.dueOccurrences(rule, now);
      if (due.isEmpty) continue;
      if (!rule.autoCreate) {
        pending.addAll(due.map((d) => PendingOccurrence(rule, d)));
        continue;
      }
      final account = await accounts.getById(rule.template.accountId);
      if (account == null) continue;
      final txns = [for (final d in due) recurrence.buildTxn(rule, d, account.currency, now)];
      await transactions.addAll(txns);
      created += txns.length;
      await recurring.update(rule.copyWith(nextDate: recurrence.nextAfter(rule, due.last)));
    }
    return GenerationResult(created: created, pending: pending);
  }

  /// Creates the transaction for a pending occurrence and advances the rule.
  Future<void> confirm(PendingOccurrence o, DateTime now) async {
    final rule = await recurring.getById(o.rule.id);
    if (rule == null) return;
    // Already confirmed or skipped (e.g. a double tap): don't create it twice.
    if (o.date.isBefore(rule.nextDate)) return;
    final account = await accounts.getById(rule.template.accountId);
    if (account == null) return;
    await transactions.add(recurrence.buildTxn(rule, o.date, account.currency, now));
    await _advancePast(rule, o.date);
  }

  /// Skips a pending occurrence without creating a transaction.
  Future<void> skip(PendingOccurrence o) async {
    final rule = await recurring.getById(o.rule.id);
    if (rule == null) return;
    await _advancePast(rule, o.date);
  }

  Future<void> _advancePast(RecurringRule rule, DateTime date) async {
    final next = recurrence.nextAfter(rule, date);
    if (next.isAfter(rule.nextDate)) {
      await recurring.update(rule.copyWith(nextDate: next));
    }
  }
}
