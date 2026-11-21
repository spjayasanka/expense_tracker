import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/data/services/app_lock_service.dart';
import 'package:pennyfold/data/services/export_import_service.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';

import '../helpers/test_db.dart';

void main() {
  group('CSV import', () {
    const importer = CsvImporter();
    const csv = 'Date;Amount;Category;Description\n'
        '2026-03-01;-12,50;Food;Lunch\n'
        '2026-03-02;2500;Salary;March pay\n'
        'not a date;5;Food;bad\n'
        '2026-03-03;-7.25;Coffee shop;Latte\n';

    test('decodes, guesses columns and parses rows', () {
      final grid = importer.decode(csv);
      expect(grid.first, ['Date', 'Amount', 'Category', 'Description']);
      final guess = importer.guessColumns(grid.first);
      expect(guess, {'date': 0, 'amount': 1, 'category': 2, 'note': 3});

      const acc = Account(id: 1, name: 'Cash', type: AccountType.cash, currency: 'USD',
          initialBalance: 0, icon: 'wallet', color: 0);
      final result = importer.parse(
        grid,
        const ImportMapping(dateColumn: 0, amountColumn: 1, categoryColumn: 2, noteColumn: 3, defaultAccountId: 1),
        {1: acc},
      );
      expect(result.rows, hasLength(3));
      expect(result.skippedLines, [4]);
      expect(result.rows[0].type, TxnType.expense);
      expect(result.rows[0].amount, 1250);
      expect(result.rows[1].type, TxnType.income);
      expect(result.rows[1].amount, 250000);
      expect(result.rows[2].categoryName, 'Coffee shop');
    });

    test('commits rows and creates missing categories once', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash');
      final accounts = {for (final a in await r.accounts.getAll()) a.id: a};
      final grid = importer.decode(csv);
      final parsed = importer.parse(
        grid,
        ImportMapping(dateColumn: 0, amountColumn: 1, categoryColumn: 2, noteColumn: 3, defaultAccountId: cash),
        accounts,
      );
      final before = (await r.categories.getAll()).length;
      final n = await importer.commit(parsed.rows,
          transactions: r.transactions, categories: r.categories, accountsById: accounts);
      expect(n, 3);
      expect(await r.transactions.count(), 3);
      // "Food" and "Salary" exist already; only "Coffee shop" is new.
      expect((await r.categories.getAll()).length, before + 1);
    });

    test('export CSV round-trips through import', () async {
      final r = Repos(newTestDb());
      addTearDown(r.db.close);
      final cash = await r.account('Cash');
      final food = (await r.categories.getAll()).firstWhere((c) => c.name == 'Food').id;
      await r.txn(type: TxnType.expense, amount: 999, accountId: cash, categoryId: food, note: 'Say "cheese", ok');
      final accounts = {for (final a in await r.accounts.getAll()) a.id: a};
      final cats = {for (final c in await r.categories.getAll()) c.id: c};
      final bytes = const ExportService().toCsv(await r.transactions.query(const TxnFilter()), accounts, cats);
      final grid = importer.decode(utf8.decode(bytes));
      expect(grid[1][1], 'expense');
      expect(grid[1][2], '9.99');
      expect(grid[1][8], 'Say "cheese", ok');

      expect(grid[1][4], 'Cash');

      final xlsx = const ExportService().toXlsx(await r.transactions.query(const TxnFilter()), accounts, cats);
      expect(xlsx.sublist(0, 2), [0x50, 0x4B]); // a ZIP container (xlsx)
    });
  });

  group('CSV import edge cases', () {
    const importer = CsvImporter();
    const acc = Account(id: 1, name: 'Cash', type: AccountType.cash, currency: 'USD',
        initialBalance: 0, icon: 'wallet', color: 0);

    test('European file: "1.500,00" and "1.500" both mean fifteen hundred', () {
      final grid = importer.decode('Date;Amount\n2026-03-01;1.500,00\n2026-03-02;1.500\n2026-03-03;12,50\n');
      final r = importer.parse(grid, const ImportMapping(dateColumn: 0, amountColumn: 1, defaultAccountId: 1), {1: acc});
      expect(r.rows.map((e) => e.amount), [150000, 150000, 1250]);
    });

    test('unknown account name is skipped, not put in the default account', () {
      final grid = importer.decode('Date;Amount;Account\n2026-03-01;5;Savings\n2026-03-02;6;cash\n');
      final r = importer.parse(
        grid,
        const ImportMapping(dateColumn: 0, amountColumn: 1, accountColumn: 2, defaultAccountId: 1),
        {1: acc},
      );
      expect(r.rows, hasLength(1));
      expect(r.skippedLines, [2]);
    });

    test('impossible dates are rejected instead of rolled over', () {
      expect(importer.parseDate('2024-02-30', 'dd/MM/yyyy'), isNull);
      expect(importer.parseDate('2024-02-29', 'dd/MM/yyyy'), DateTime(2024, 2, 29));
    });
  });

  group('PIN hashing', () {
    const hasher = PinHasher(iterations: 1000);
    test('same PIN + salt verifies, different PIN or salt does not', () {
      final salt = PinHasher.randomSalt();
      final h = hasher.hash('1234', salt);
      expect(PinHasher.equals(h, hasher.hash('1234', salt)), isTrue);
      expect(PinHasher.equals(h, hasher.hash('1235', salt)), isFalse);
      expect(PinHasher.equals(h, hasher.hash('1234', PinHasher.randomSalt())), isFalse);
      expect(h, isNot(contains('1234')));
    });

    test('matches the PBKDF2-HMAC-SHA256 reference vector', () {
      // RFC 7914 §11 test vector: P="passwd", S="salt", c=1, dkLen=64.
      final dk = const PinHasher(iterations: 1).derive('passwd', utf8.encode('salt'), length: 64);
      expect(
        dk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });
  });
}
