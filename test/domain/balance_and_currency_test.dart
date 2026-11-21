import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/core/utils/date_range.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';
import 'package:pennyfold/domain/services/balance_calculator.dart';
import 'package:pennyfold/domain/services/currency_converter.dart';

import '../helpers/test_db.dart';

void main() {
  group('CurrencyConverter', () {
    final c = CurrencyConverter(mainCurrency: 'USD', rates: {'EUR': 1.10, 'JPY': 0.0067, 'KWD': 3.25});

    test('main currency passes through', () {
      expect(c.toMain(12345, 'USD'), 12345);
    });
    test('converts with rate and rounds to minor units', () {
      expect(c.toMain(1000, 'EUR'), 1100); // €10.00 → $11.00
      expect(c.toMain(333, 'EUR'), 366); // €3.33 → $3.663 → 366
    });
    test('handles differing decimals', () {
      expect(c.toMain(10000, 'JPY'), 6700); // ¥10,000 → $67.00
      expect(c.toMain(1000, 'KWD'), 325); // KD1.000 → $3.25
    });
    test('cross conversion through main currency', () {
      expect(c.convert(1100, 'USD', 'EUR'), 1000);
    });
    test('missing rates fall back to 1:1 and are reported', () {
      expect(c.toMain(500, 'GBP'), 500);
      expect(c.missingRates(['USD', 'EUR', 'GBP']), {'GBP'});
    });
    test('sums multiple currencies', () {
      expect(c.sumToMain({'USD': 100, 'EUR': 1000}), 1200);
    });
  });

  group('BalanceCalculator', () {
    const calc = BalanceCalculator();
    Account acc(int id, {String cur = 'USD', int initial = 0, bool include = true, bool archived = false}) =>
        Account(
          id: id,
          name: 'A$id',
          type: AccountType.cash,
          currency: cur,
          initialBalance: initial,
          icon: 'wallet',
          color: 0,
          includeInTotal: include,
          isArchived: archived,
        );
    Txn t(TxnType type, int amount, int account, {int? to, int? toAmount}) => Txn(
          id: 0,
          type: type,
          amount: amount,
          currency: 'USD',
          accountId: account,
          toAccountId: to,
          toAmount: toAmount,
          date: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('initial + income − expense ± transfers', () {
      final flows = calc.flowsFromTransactions([
        t(TxnType.income, 10000, 1),
        t(TxnType.expense, 2500, 1),
        t(TxnType.transfer, 3000, 1, to: 2),
        t(TxnType.expense, 500, 2),
      ]);
      expect(calc.accountBalance(acc(1, initial: 1000), flows[1]!), 1000 + 10000 - 2500 - 3000);
      expect(calc.accountBalance(acc(2), flows[2]!), 3000 - 500);
    });

    test('transfers do not change the combined total', () {
      final accounts = [acc(1, initial: 5000), acc(2, initial: 0)];
      final before = calc.totalBalance(calc.balances(accounts, {}), CurrencyConverter(mainCurrency: 'USD'));
      final flows = calc.flowsFromTransactions([t(TxnType.transfer, 2000, 1, to: 2)]);
      final after = calc.totalBalance(calc.balances(accounts, flows), CurrencyConverter(mainCurrency: 'USD'));
      expect(after, before);
    });

    test('total excludes excluded/archived accounts and converts currency', () {
      final accounts = [
        acc(1, initial: 1000),
        acc(2, cur: 'EUR', initial: 1000),
        acc(3, initial: 99999, include: false),
        acc(4, initial: 77777, archived: true),
      ];
      final conv = CurrencyConverter(mainCurrency: 'USD', rates: {'EUR': 1.5});
      expect(calc.totalBalance(calc.balances(accounts, {}), conv), 1000 + 1500);
    });

    test('cross-currency transfer credits toAmount', () {
      final flows = calc.flowsFromTransactions([t(TxnType.transfer, 1000, 1, to: 2, toAmount: 900)]);
      expect(flows[1]!.transferOut, 1000);
      expect(flows[2]!.transferIn, 900);
    });
  });

  group('SQL aggregates match the pure calculator', () {
    test('account flows from the database', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash', initial: 1000);
      final bank = await r.account('Bank', currency: 'EUR');
      await r.txn(type: TxnType.income, amount: 5000, accountId: cash);
      await r.txn(type: TxnType.expense, amount: 1200, accountId: cash);
      await r.txn(type: TxnType.transfer, amount: 2000, accountId: cash, toAccountId: bank, toAmount: 1800);
      final flows = await r.accounts.flows();
      const calc = BalanceCalculator();
      final accounts = await r.accounts.getAll();
      final balances = calc.balances(accounts, flows);
      expect(balances.firstWhere((b) => b.account.id == cash).balance, 1000 + 5000 - 1200 - 2000);
      expect(balances.firstWhere((b) => b.account.id == bank).balance, 1800);
      final total = calc.totalBalance(
          balances, CurrencyConverter(mainCurrency: 'USD', rates: {'EUR': 1.25}));
      expect(total, 2800 + 2250);
    });

    test('category totals and search', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash');
      final cats = await r.categories.getAll();
      final food = cats.firstWhere((c) => c.name == 'Food').id;
      await r.txn(type: TxnType.expense, amount: 1500, accountId: cash, categoryId: food, note: 'Pizza night');
      await r.txn(type: TxnType.expense, amount: 700, accountId: cash, categoryId: food);
      final totals = await r.transactions.categoryTotals(DateRange(kAllTimeStart, kAllTimeEnd));
      final foodTotal = totals.firstWhere((t) => t.categoryId == food);
      expect(foodTotal.amount, 2200);
      expect(foodTotal.count, 2);

      final byNote = await r.transactions.query(const TxnFilter(search: 'pizza'));
      expect(byNote.length, 1);
      final byCategory = await r.transactions.query(const TxnFilter(search: 'foo'));
      expect(byCategory.length, 2);
      final byAmount = await r.transactions.query(const TxnFilter(search: '7'));
      expect(byAmount.single.amount, 700);
    });
  });
}
