import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/icons/icon_library.dart';
import '../../core/money/money_format.dart';
import '../../core/utils/date_range.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/balance_calculator.dart';
import '../db/app_database.dart';
import 'mappers.dart';

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this.db);
  final AppDatabase db;

  SimpleSelectStatement<$AccountsTable, AccountRow> _all() => db.select(db.accounts)
    ..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.id)]);

  @override
  Stream<List<Account>> watchAll() =>
      _all().watch().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<Account>> getAll() async => (await _all().get()).map((r) => r.toDomain()).toList();

  @override
  Future<Account?> getById(int id) async =>
      (await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull())
          ?.toDomain();

  @override
  Future<int> add(Account account) async {
    final maxOrder = await _maxSortOrder();
    return db
        .into(db.accounts)
        .insert(account.copyWith(sortOrder: maxOrder + 1).toCompanion());
  }

  Future<int> _maxSortOrder() async {
    final row = await db
        .customSelect('SELECT COALESCE(MAX(sort_order), -1) AS m FROM accounts')
        .getSingle();
    return row.read<int>('m');
  }

  @override
  Future<void> update(Account account) =>
      db.update(db.accounts).replace(account.toCompanion(withId: true));

  @override
  Future<void> delete(int id) => db.transaction(() async {
        // Transfers between this account and another must not vanish from the
        // other account's history (that would change its balance). Keep them
        // there as plain income/expense instead.
        // Money that came *from* this account becomes income on the other one.
        await db.customUpdate(
          '''
UPDATE transactions SET
  type = 'income',
  account_id = to_account_id,
  amount = COALESCE(to_amount, amount),
  currency = (SELECT currency FROM accounts WHERE id = transactions.to_account_id),
  to_account_id = NULL,
  to_amount = NULL,
  category_id = NULL
WHERE type = 'transfer' AND account_id = ? AND to_account_id IS NOT NULL AND to_account_id != ?
''',
          variables: [Variable.withInt(id), Variable.withInt(id)],
          updates: {db.transactions},
        );
        // Money that went *to* this account becomes an expense on the other one.
        await db.customUpdate(
          '''
UPDATE transactions SET
  type = 'expense',
  to_account_id = NULL,
  to_amount = NULL,
  category_id = NULL
WHERE type = 'transfer' AND to_account_id = ? AND account_id != ?
''',
          variables: [Variable.withInt(id), Variable.withInt(id)],
          updates: {db.transactions},
        );
        await (db.delete(db.transactions)
              ..where((t) => t.accountId.equals(id) | t.toAccountId.equals(id)))
            .go();
        await (db.delete(db.recurringRules)
              ..where((r) => r.accountId.equals(id) | r.toAccountId.equals(id)))
            .go();
        await (db.delete(db.accounts)..where((a) => a.id.equals(id))).go();
      });

  @override
  Future<void> reorder(List<int> orderedIds) => db.batch((b) {
        for (var i = 0; i < orderedIds.length; i++) {
          b.update(db.accounts, AccountsCompanion(sortOrder: Value(i)),
              where: ($AccountsTable a) => a.id.equals(orderedIds[i]));
        }
      });

  @override
  Future<int> transactionCount(int accountId) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE account_id = ? OR to_account_id = ?',
      variables: [Variable.withInt(accountId), Variable.withInt(accountId)],
    ).getSingle();
    return row.read<int>('c');
  }

  static const _flowsSql = '''
SELECT account_id AS acc, type AS kind, SUM(amount) AS total
  FROM transactions WHERE date >= ? AND date < ?
  GROUP BY account_id, type
UNION ALL
SELECT to_account_id AS acc, 'transfer_in' AS kind, SUM(COALESCE(to_amount, amount)) AS total
  FROM transactions
  WHERE type = 'transfer' AND to_account_id IS NOT NULL AND date >= ? AND date < ?
  GROUP BY to_account_id
''';

  List<Variable> _rangeVars(DateRange? range) {
    final s = Variable<DateTime>(range?.start ?? kAllTimeStart);
    final e = Variable<DateTime>(range?.end ?? kAllTimeEnd);
    return [s, e, s, e];
  }

  Map<int, AccountFlows> _flowsFromRows(List<QueryRow> rows) {
    final map = <int, AccountFlows>{};
    for (final r in rows) {
      final acc = r.read<int>('acc');
      final total = r.read<int>('total');
      final f = switch (r.read<String>('kind')) {
        'expense' => AccountFlows(expense: total),
        'income' => AccountFlows(income: total),
        'transfer' => AccountFlows(transferOut: total),
        _ => AccountFlows(transferIn: total),
      };
      map[acc] = (map[acc] ?? AccountFlows.zero) + f;
    }
    return map;
  }

  @override
  Stream<Map<int, AccountFlows>> watchFlows() => db
      .customSelect(_flowsSql, variables: _rangeVars(null), readsFrom: {db.transactions})
      .watch()
      .map(_flowsFromRows);

  @override
  Future<Map<int, AccountFlows>> flows({DateRange? range}) async =>
      _flowsFromRows(await db.customSelect(_flowsSql, variables: _rangeVars(range)).get());

  @override
  Future<List<AccountDayFlow>> dailyFlows(DateRange range) async {
    const sql = '''
SELECT date(date, 'unixepoch', 'localtime') AS d, account_id AS acc, type AS kind, SUM(amount) AS total
  FROM transactions WHERE date >= ? AND date < ?
  GROUP BY d, account_id, type
UNION ALL
SELECT date(date, 'unixepoch', 'localtime') AS d, to_account_id AS acc, 'transfer_in' AS kind,
       SUM(COALESCE(to_amount, amount)) AS total
  FROM transactions
  WHERE type = 'transfer' AND to_account_id IS NOT NULL AND date >= ? AND date < ?
  GROUP BY d, to_account_id
''';
    final rows = await db.customSelect(sql, variables: _rangeVars(range)).get();
    final map = <(String, int), AccountFlows>{};
    for (final r in rows) {
      final key = (r.read<String>('d'), r.read<int>('acc'));
      final total = r.read<int>('total');
      final f = switch (r.read<String>('kind')) {
        'expense' => AccountFlows(expense: total),
        'income' => AccountFlows(income: total),
        'transfer' => AccountFlows(transferOut: total),
        _ => AccountFlows(transferIn: total),
      };
      map[key] = (map[key] ?? AccountFlows.zero) + f;
    }
    final out = [
      for (final e in map.entries) AccountDayFlow(DateTime.parse(e.key.$1), e.key.$2, e.value),
    ]..sort((a, b) => a.day.compareTo(b.day));
    return out;
  }
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this.db);
  final AppDatabase db;

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _all() => db.select(db.categories)
    ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)]);

  @override
  Stream<List<Category>> watchAll() =>
      _all().watch().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<Category>> getAll() async => (await _all().get()).map((r) => r.toDomain()).toList();

  @override
  Future<int> add(Category category) async {
    final row = await db.customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) AS m FROM categories WHERE type = ?',
      variables: [Variable.withString(category.type.name)],
    ).getSingle();
    return db
        .into(db.categories)
        .insert(category.copyWith(sortOrder: row.read<int>('m') + 1).toCompanion());
  }

  @override
  Future<void> update(Category category) =>
      db.update(db.categories).replace(category.toCompanion(withId: true));

  @override
  Future<void> reorder(List<int> orderedIds) => db.batch((b) {
        for (var i = 0; i < orderedIds.length; i++) {
          b.update(db.categories, CategoriesCompanion(sortOrder: Value(i)),
              where: ($CategoriesTable c) => c.id.equals(orderedIds[i]));
        }
      });

  @override
  Future<int> transactionCount(int categoryId) async {
    final row = await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      variables: [Variable.withInt(categoryId)],
    ).getSingle();
    return row.read<int>('c');
  }

  @override
  Future<void> merge({required int fromId, required int intoId}) {
    if (fromId == intoId) return Future.value();
    return db.transaction(() async {
      await (db.update(db.transactions)..where((t) => t.categoryId.equals(fromId)))
          .write(TransactionsCompanion(categoryId: Value(intoId)));
      await (db.update(db.recurringRules)..where((r) => r.categoryId.equals(fromId)))
          .write(RecurringRulesCompanion(categoryId: Value(intoId)));
      // A category may have several budgets (e.g. weekly + monthly).
      final intoHasBudget = (await (db.select(db.budgets)
                ..where((b) => b.categoryId.equals(intoId)))
              .get())
          .isNotEmpty;
      if (intoHasBudget) {
        await (db.delete(db.budgets)..where((b) => b.categoryId.equals(fromId))).go();
      } else {
        await (db.update(db.budgets)..where((b) => b.categoryId.equals(fromId)))
            .write(BudgetsCompanion(categoryId: Value(intoId)));
      }
      await (db.delete(db.categories)..where((c) => c.id.equals(fromId))).go();
    });
  }

  @override
  Future<void> deleteWithTransactions(int id) => db.transaction(() async {
        await (db.delete(db.transactions)..where((t) => t.categoryId.equals(id))).go();
        await (db.delete(db.recurringRules)..where((r) => r.categoryId.equals(id))).go();
        await (db.delete(db.budgets)..where((b) => b.categoryId.equals(id))).go();
        await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
      });

  @override
  Future<int> findOrCreate(String name, CategoryType type) async {
    final trimmed = name.trim();
    final existing = await (db.select(db.categories)
          ..where((c) => c.name.lower().equals(trimmed.toLowerCase()) & c.type.equals(type.name))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final color = kPaletteColors[Random().nextInt(kPaletteColors.length)];
    return add(Category(id: 0, name: trimmed, type: type, icon: kFallbackIcon, color: color));
  }
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this.db);
  final AppDatabase db;

  SimpleSelectStatement<$TransactionsTable, TxnRow> _select(TxnFilter f) {
    final q = db.select(db.transactions);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      final range = f.range;
      if (range != null) {
        e = e &
            t.date.isBiggerOrEqualValue(range.start) &
            t.date.isSmallerThanValue(range.end);
      }
      final accs = f.accountIds;
      if (accs != null && accs.isNotEmpty) {
        e = e & (t.accountId.isIn(accs) | t.toAccountId.isIn(accs));
      }
      final cats = f.categoryIds;
      if (cats != null && cats.isNotEmpty) {
        e = e & t.categoryId.isIn(cats);
      }
      final types = f.types;
      if (types != null && types.isNotEmpty) {
        e = e & t.type.isIn(types.map((x) => x.name));
      }
      final search = f.search?.trim();
      if (search != null && search.isNotEmpty) {
        final pattern = '%${search.replaceAll('%', '').replaceAll('_', '')}%';
        final catIds = db.selectOnly(db.categories)
          ..addColumns([db.categories.id])
          ..where(db.categories.name.like(pattern));
        Expression<bool> s = t.note.like(pattern) | t.categoryId.isInQuery(catIds);
        final amounts = <int>{
          for (final dec in const [0, 2, 3])
            if (parseMinorUnits(search, dec) case final v?) v.abs(),
        };
        if (amounts.isNotEmpty) s = s | t.amount.isIn(amounts);
        e = e & s;
      }
      return e;
    });
    q.orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)]);
    if (f.limit != null) q.limit(f.limit!);
    return q;
  }

  @override
  Stream<List<Txn>> watch(TxnFilter filter) =>
      _select(filter).watch().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<Txn>> query(TxnFilter filter) async =>
      (await _select(filter).get()).map((r) => r.toDomain()).toList();

  @override
  Future<Txn?> getById(int id) async =>
      (await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull())
          ?.toDomain();

  @override
  Future<int> add(Txn txn) => db.into(db.transactions).insert(txn.toCompanion());

  @override
  Future<void> addAll(List<Txn> txns) => db.batch((b) {
        b.insertAll(db.transactions, [for (final t in txns) t.toCompanion()]);
      });

  @override
  Future<void> update(Txn txn) =>
      db.update(db.transactions).replace(txn.toCompanion(withId: true));

  @override
  Future<Txn?> delete(int id) => db.transaction(() async {
        final existing = await getById(id);
        if (existing == null) return null;
        await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
        return existing;
      });

  @override
  Future<void> restore(Txn txn) => db
      .into(db.transactions)
      .insert(txn.toCompanion(withId: true), mode: InsertMode.insertOrReplace);

  @override
  Future<int> count() async {
    final row = await db.customSelect('SELECT COUNT(*) AS c FROM transactions').getSingle();
    return row.read<int>('c');
  }

  Selectable<QueryRow> _categoryTotals(DateRange range, Set<int>? accountIds) {
    final vars = <Variable>[Variable<DateTime>(range.start), Variable<DateTime>(range.end)];
    var accountClause = '';
    if (accountIds != null && accountIds.isNotEmpty) {
      accountClause = 'AND account_id IN (${List.filled(accountIds.length, '?').join(',')})';
      vars.addAll(accountIds.map(Variable.withInt));
    }
    return db.customSelect(
      '''
SELECT type, category_id, currency, SUM(amount) AS total, COUNT(*) AS cnt
  FROM transactions
  WHERE type != 'transfer' AND date >= ? AND date < ? $accountClause
  GROUP BY type, category_id, currency
''',
      variables: vars,
      readsFrom: {db.transactions},
    );
  }

  List<CategoryTotal> _mapTotals(List<QueryRow> rows) => [
        for (final r in rows)
          CategoryTotal(
            type: TxnType.values.byName(r.read<String>('type')),
            categoryId: r.readNullable<int>('category_id'),
            currency: r.read<String>('currency'),
            amount: r.read<int>('total'),
            count: r.read<int>('cnt'),
          ),
      ];

  @override
  Stream<List<CategoryTotal>> watchCategoryTotals(DateRange range, {Set<int>? accountIds}) =>
      _categoryTotals(range, accountIds).watch().map(_mapTotals);

  @override
  Future<List<CategoryTotal>> categoryTotals(DateRange range, {Set<int>? accountIds}) async =>
      _mapTotals(await _categoryTotals(range, accountIds).get());

  @override
  Future<Map<String, int>> expenseByCurrency(DateRange range, {int? categoryId}) async {
    final vars = <Variable>[Variable<DateTime>(range.start), Variable<DateTime>(range.end)];
    var clause = '';
    if (categoryId != null) {
      clause = 'AND category_id = ?';
      vars.add(Variable.withInt(categoryId));
    }
    final rows = await db.customSelect(
      '''
SELECT currency, SUM(amount) AS total FROM transactions
  WHERE type = 'expense' AND date >= ? AND date < ? $clause
  GROUP BY currency
''',
      variables: vars,
    ).get();
    return {for (final r in rows) r.read<String>('currency'): r.read<int>('total')};
  }

  @override
  Future<DateTime?> firstDate() async {
    final q = db.selectOnly(db.transactions)..addColumns([db.transactions.date.min()]);
    return (await q.getSingle()).read(db.transactions.date.min());
  }
}

// ---------------------------------------------------------------------------
// Budgets, recurring rules, exchange rates, settings
// ---------------------------------------------------------------------------

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this.db);
  final AppDatabase db;

  @override
  Stream<List<Budget>> watchAll() =>
      db.select(db.budgets).watch().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<Budget>> getAll() async =>
      (await db.select(db.budgets).get()).map((r) => r.toDomain()).toList();

  @override
  Future<int> add(Budget budget) => db.into(db.budgets).insert(budget.toCompanion());

  @override
  Future<void> update(Budget budget) =>
      db.update(db.budgets).replace(budget.toCompanion(withId: true));

  @override
  Future<void> delete(int id) => (db.delete(db.budgets)..where((b) => b.id.equals(id))).go();
}

class DriftRecurringRepository implements RecurringRepository {
  DriftRecurringRepository(this.db);
  final AppDatabase db;

  SimpleSelectStatement<$RecurringRulesTable, RecurringRow> _all() =>
      db.select(db.recurringRules)..orderBy([(r) => OrderingTerm.asc(r.nextDate)]);

  @override
  Stream<List<RecurringRule>> watchAll() =>
      _all().watch().map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<RecurringRule>> getAll() async =>
      (await _all().get()).map((r) => r.toDomain()).toList();

  @override
  Future<RecurringRule?> getById(int id) async =>
      (await (db.select(db.recurringRules)..where((r) => r.id.equals(id))).getSingleOrNull())
          ?.toDomain();

  @override
  Future<int> add(RecurringRule rule) => db.into(db.recurringRules).insert(rule.toCompanion());

  @override
  Future<void> update(RecurringRule rule) =>
      db.update(db.recurringRules).replace(rule.toCompanion(withId: true));

  @override
  Future<void> delete(int id) =>
      (db.delete(db.recurringRules)..where((r) => r.id.equals(id))).go();
}

class DriftExchangeRateRepository implements ExchangeRateRepository {
  DriftExchangeRateRepository(this.db);
  final AppDatabase db;

  @override
  Stream<List<ExchangeRate>> watchAll() => db
      .select(db.exchangeRates)
      .watch()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  @override
  Future<List<ExchangeRate>> getAll() async =>
      (await db.select(db.exchangeRates).get()).map((r) => r.toDomain()).toList();

  @override
  Future<void> upsert(ExchangeRate rate) => db.into(db.exchangeRates).insertOnConflictUpdate(
        ExchangeRatesCompanion.insert(
          currencyCode: rate.currencyCode.toUpperCase(),
          rateToMain: rate.rateToMain,
          updatedAt: rate.updatedAt,
        ),
      );

  @override
  Future<void> delete(String currencyCode) => (db.delete(db.exchangeRates)
        ..where((r) => r.currencyCode.equals(currencyCode.toUpperCase())))
      .go();

  @override
  Future<void> clear() => db.delete(db.exchangeRates).go();
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this.db);
  final AppDatabase db;

  AppSettings _fromRows(List<SettingRow> rows) =>
      AppSettings.fromMap({for (final r in rows) r.key: r.value});

  @override
  Stream<AppSettings> watch() => db.select(db.settings).watch().map(_fromRows);

  @override
  Future<AppSettings> get() async => _fromRows(await db.select(db.settings).get());

  @override
  Future<void> save(AppSettings settings) => db.batch((b) {
        b.insertAllOnConflictUpdate(db.settings, [
          for (final e in settings.toMap().entries)
            SettingsCompanion.insert(key: e.key, value: e.value),
        ]);
      });

  @override
  Future<String?> getValue(String key) async =>
      (await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> setValue(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
    } else {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    }
  }
}
