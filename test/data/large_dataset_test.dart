import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/core/utils/date_range.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';

import '../helpers/test_db.dart';

void main() {
  test('12,000 transactions: aggregates and queries stay fast', () async {
    final r = Repos(newTestDb());
    addTearDown(r.db.close);
    final cash = await r.account('Cash');
    final cats = (await r.categories.getAll()).where((c) => c.type == CategoryType.expense).toList();
    final start = DateTime(2023, 1, 1);
    final now = DateTime(2026, 1, 1);
    final txns = [
      for (var i = 0; i < 12000; i++)
        Txn(
          id: 0,
          type: i % 10 == 0 ? TxnType.income : TxnType.expense,
          amount: 100 + i % 5000,
          currency: 'USD',
          accountId: cash,
          categoryId: cats[i % cats.length].id,
          date: start.add(Duration(hours: i * 2)),
          note: i % 7 == 0 ? 'coffee $i' : '',
          createdAt: now,
          updatedAt: now,
        ),
    ];
    for (var i = 0; i < txns.length; i += 1000) {
      await r.transactions.addAll(txns.sublist(i, i + 1000));
    }
    expect(await r.transactions.count(), 12000);

    final sw = Stopwatch()..start();
    final totals = await r.transactions.categoryTotals(DateRange(kAllTimeStart, kAllTimeEnd));
    final flows = await r.accounts.flows();
    final month = await r.transactions.query(TxnFilter(range: DateRange(DateTime(2024, 3), DateTime(2024, 4))));
    final search = await r.transactions.query(const TxnFilter(search: 'coffee'));
    final daily = await r.accounts.dailyFlows(DateRange(start, now));
    sw.stop();

    final expectedExpense = txns.where((t) => t.type == TxnType.expense).fold<int>(0, (s, t) => s + t.amount);
    expect(totals.where((t) => t.type == TxnType.expense).fold<int>(0, (s, t) => s + t.amount), expectedExpense);
    expect(flows[cash]!.expense, expectedExpense);
    expect(month, isNotEmpty);
    expect(search.length, txns.where((t) => t.note.contains('coffee')).length);
    expect(daily, isNotEmpty);
    // Generous bound for slow CI machines; typically well under 500 ms.
    expect(sw.elapsedMilliseconds, lessThan(3000), reason: 'took ${sw.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('Aggregates + queries over 12k rows: ${sw.elapsedMilliseconds} ms');
  });
}
