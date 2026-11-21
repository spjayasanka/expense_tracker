import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pennyfold/data/db/app_database.dart';
import 'package:pennyfold/data/repositories/drift_repositories.dart';
import 'package:pennyfold/domain/entities/entities.dart';

AppDatabase newTestDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // closeStreamsSynchronously avoids pending timers in widget tests.
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}

class Repos {
  Repos(this.db)
      : accounts = DriftAccountRepository(db),
        categories = DriftCategoryRepository(db),
        transactions = DriftTransactionRepository(db),
        budgets = DriftBudgetRepository(db),
        recurring = DriftRecurringRepository(db),
        rates = DriftExchangeRateRepository(db),
        settings = DriftSettingsRepository(db);

  final AppDatabase db;
  final DriftAccountRepository accounts;
  final DriftCategoryRepository categories;
  final DriftTransactionRepository transactions;
  final DriftBudgetRepository budgets;
  final DriftRecurringRepository recurring;
  final DriftExchangeRateRepository rates;
  final DriftSettingsRepository settings;

  Future<int> account(String name, {String currency = 'USD', int initial = 0, bool include = true}) =>
      accounts.add(Account(
        id: 0,
        name: name,
        type: AccountType.cash,
        currency: currency,
        initialBalance: initial,
        icon: 'wallet',
        color: 0xFF43A047,
        includeInTotal: include,
      ));

  Future<int> txn({
    required TxnType type,
    required int amount,
    required int accountId,
    String currency = 'USD',
    int? toAccountId,
    int? toAmount,
    int? categoryId,
    DateTime? date,
    String note = '',
  }) {
    final now = DateTime(2026, 1, 1);
    return transactions.add(Txn(
      id: 0,
      type: type,
      amount: amount,
      currency: currency,
      accountId: accountId,
      toAccountId: toAccountId,
      toAmount: toAmount,
      categoryId: categoryId,
      date: date ?? DateTime(2026, 3, 10, 12),
      note: note,
      createdAt: now,
      updatedAt: now,
    ));
  }
}
