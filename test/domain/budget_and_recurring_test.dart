import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/core/utils/date_range.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';
import 'package:pennyfold/domain/services/budget_calculator.dart';
import 'package:pennyfold/domain/services/currency_converter.dart';
import 'package:pennyfold/domain/services/recurrence.dart';
import 'package:pennyfold/domain/usecases/budget_service.dart';
import 'package:pennyfold/domain/usecases/recurring_generator.dart';

import '../helpers/test_db.dart';

void main() {
  const prefs = CalendarPrefs();

  group('BudgetCalculator', () {
    const calc = BudgetCalculator();
    final budget = Budget(id: 1, amount: 10000, startDate: DateTime(2026, 1, 1));

    test('progress and alert levels', () {
      final periods = [DateRange(DateTime(2026, 3), DateTime(2026, 4))];
      BudgetStatus s(int spent) =>
          calc.compute(budget: budget, periods: periods, spentPerPeriod: [spent]);
      expect(s(5000).remaining, 5000);
      expect(s(5000).alertLevel, BudgetAlertLevel.none);
      expect(s(8000).alertLevel, BudgetAlertLevel.warning);
      expect(s(10000).alertLevel, BudgetAlertLevel.exceeded);
      expect(s(12000).remaining, -2000);
    });

    test('carry-over rolls remaining (and overspend) into the next period', () {
      final b = budget.copyWith(carryOver: true);
      final periods = calc.periodsSinceStart(b, DateTime(2026, 3, 15), prefs);
      expect(periods.length, 3); // Jan, Feb, Mar
      // Jan: spent 6000 → +4000; Feb: avail 14000, spent 16000 → −2000.
      final s = calc.compute(budget: b, periods: periods, spentPerPeriod: [6000, 16000, 1000]);
      expect(s.carriedOver, -2000);
      expect(s.available, 8000);
      expect(s.remaining, 7000);
    });

    test('without carry-over nothing rolls', () {
      final periods = calc.periodsSinceStart(budget, DateTime(2026, 3, 15), prefs);
      final s = calc.compute(budget: budget, periods: periods, spentPerPeriod: [0, 0, 1000]);
      expect(s.carriedOver, 0);
      expect(s.available, 10000);
    });

    test('each alert level fires once per period', () {
      final periods = [DateRange(DateTime(2026, 3), DateTime(2026, 4))];
      final s = calc.compute(budget: budget, periods: periods, spentPerPeriod: [8500]);
      expect(calc.alertToSend(s, BudgetAlertLevel.none), BudgetAlertLevel.warning);
      expect(calc.alertToSend(s, BudgetAlertLevel.warning), BudgetAlertLevel.none);
    });
  });

  group('BudgetService with database', () {
    test('category budget spent across currencies, alerts recorded once', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final usd = await r.account('Cash');
      final eur = await r.account('Euro card', currency: 'EUR');
      final food = (await r.categories.getAll()).firstWhere((c) => c.name == 'Food').id;
      await r.budgets.add(Budget(id: 0, categoryId: food, amount: 10000, startDate: DateTime(2026, 3)));
      await r.txn(type: TxnType.expense, amount: 5000, accountId: usd, categoryId: food, date: DateTime(2026, 3, 5));
      await r.txn(
          type: TxnType.expense,
          amount: 2000,
          accountId: eur,
          currency: 'EUR',
          categoryId: food,
          date: DateTime(2026, 3, 6));
      // Outside the period: ignored.
      await r.txn(type: TxnType.expense, amount: 9999, accountId: usd, categoryId: food, date: DateTime(2026, 2, 6));

      final service = BudgetService(budgets: r.budgets, transactions: r.transactions, settings: r.settings);
      final conv = CurrencyConverter(mainCurrency: 'USD', rates: {'EUR': 1.5});
      final now = DateTime(2026, 3, 20);
      final statuses = await service.allStatuses(now, prefs, conv);
      expect(statuses.single.spent, 5000 + 3000);

      final alerts = await service.pendingAlerts(now, prefs, conv);
      expect(alerts.single.$2, BudgetAlertLevel.warning);
      expect(await service.pendingAlerts(now, prefs, conv), isEmpty);

      await r.txn(type: TxnType.expense, amount: 2500, accountId: usd, categoryId: food, date: DateTime(2026, 3, 7));
      final again = await service.pendingAlerts(now, prefs, conv);
      expect(again.single.$2, BudgetAlertLevel.exceeded);
    });
  });

  group('Recurrence', () {
    const rec = Recurrence();
    RecurringRule rule(RecurrenceFrequency f, DateTime start, {int interval = 1, DateTime? end, bool auto = true}) =>
        RecurringRule(
          id: 1,
          template: const TxnTemplate(type: TxnType.expense, amount: 1000, accountId: 1, categoryId: 1),
          frequency: f,
          interval: interval,
          startDate: start,
          nextDate: start,
          endDate: end,
          autoCreate: auto,
        );

    test('monthly on the 31st clamps without drifting', () {
      final r = rule(RecurrenceFrequency.monthly, DateTime(2026, 1, 31));
      final due = rec.dueOccurrences(r, DateTime(2026, 5, 31));
      expect(due, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
      ]);
    });

    test('custom interval: every 2 weeks', () {
      final r = rule(RecurrenceFrequency.weekly, DateTime(2026, 1, 1), interval: 2);
      expect(rec.nextAfter(r, DateTime(2026, 1, 1)), DateTime(2026, 1, 15));
      expect(rec.dueOccurrences(r, DateTime(2026, 2, 1)).length, 3); // 1, 15, 29 Jan
    });

    test('yearly on Feb 29 falls back to Feb 28', () {
      final r = rule(RecurrenceFrequency.yearly, DateTime(2028, 2, 29));
      expect(rec.nextAfter(r, DateTime(2028, 3, 1)), DateTime(2029, 2, 28));
      expect(rec.occurrence(r.startDate, r.frequency, 1, 4), DateTime(2032, 2, 29));
    });

    test('end date and pause are respected', () {
      final r = rule(RecurrenceFrequency.daily, DateTime(2026, 1, 1), end: DateTime(2026, 1, 3));
      expect(rec.dueOccurrences(r, DateTime(2026, 1, 10)).length, 3);
      expect(rec.dueOccurrences(r.copyWith(isPaused: true), DateTime(2026, 1, 10)), isEmpty);
    });
  });

  group('RecurringGenerator', () {
    test('creates missed occurrences once and advances nextDate', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash', currency: 'EUR');
      final bills = (await r.categories.getAll()).firstWhere((c) => c.name == 'Bills').id;
      await r.recurring.add(RecurringRule(
        id: 0,
        template: TxnTemplate(type: TxnType.expense, amount: 4500, accountId: cash, categoryId: bills, note: 'Rent'),
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 15),
        nextDate: DateTime(2026, 1, 15),
      ));
      final gen = RecurringGenerator(recurring: r.recurring, transactions: r.transactions, accounts: r.accounts);

      final result = await gen.run(DateTime(2026, 4, 20));
      expect(result.created, 4); // Jan, Feb, Mar, Apr
      final txns = await r.transactions.query(const TxnFilter());
      expect(txns.length, 4);
      expect(txns.every((t) => t.currency == 'EUR' && t.recurringId != null && t.note == 'Rent'), isTrue);
      expect((await r.recurring.getAll()).single.nextDate, DateTime(2026, 5, 15));

      // Running again the same day creates nothing new (idempotent).
      expect((await gen.run(DateTime(2026, 4, 20))).created, 0);
      expect(await r.transactions.count(), 4);
    });

    test('confirmation rules wait for the user', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash');
      await r.recurring.add(RecurringRule(
        id: 0,
        template: TxnTemplate(type: TxnType.income, amount: 300000, accountId: cash),
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 3, 1),
        nextDate: DateTime(2026, 3, 1),
        autoCreate: false,
      ));
      final gen = RecurringGenerator(recurring: r.recurring, transactions: r.transactions, accounts: r.accounts);
      final result = await gen.run(DateTime(2026, 4, 2));
      expect(result.created, 0);
      expect(result.pending.length, 2);
      expect(await r.transactions.count(), 0);

      await gen.confirm(result.pending[0], DateTime(2026, 4, 2));
      await gen.skip(result.pending[1]);
      expect(await r.transactions.count(), 1);
      expect((await r.recurring.getAll()).single.nextDate, DateTime(2026, 5, 1));
      expect((await gen.run(DateTime(2026, 4, 2))).pending, isEmpty);
    });

    test('paused rules generate nothing', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash');
      await r.recurring.add(RecurringRule(
        id: 0,
        template: TxnTemplate(type: TxnType.expense, amount: 100, accountId: cash),
        frequency: RecurrenceFrequency.daily,
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 1, 1),
        isPaused: true,
      ));
      final gen = RecurringGenerator(recurring: r.recurring, transactions: r.transactions, accounts: r.accounts);
      expect((await gen.run(DateTime(2026, 2, 1))).created, 0);
    });
  });
}
