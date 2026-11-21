import 'package:drift/drift.dart';

import '../../domain/entities/entities.dart';

@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => textEnum<CategoryType>()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
}

@DataClassName('TxnRow')
@TableIndex(name: 'idx_txn_date', columns: {#date})
@TableIndex(name: 'idx_txn_account', columns: {#accountId})
@TableIndex(name: 'idx_txn_to_account', columns: {#toAccountId})
@TableIndex(name: 'idx_txn_category', columns: {#categoryId})
@TableIndex(name: 'idx_txn_recurring', columns: {#recurringId})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TxnType>()();

  /// Positive minor units of [currency].
  IntColumn get amount => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();

  /// Amount credited to the destination account (cross-currency transfers).
  IntColumn get toAmount => integer().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get recurringId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get amount => integer()();
  TextColumn get period => textEnum<BudgetPeriod>()();
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startDate => dateTime()();
}

@DataClassName('RecurringRow')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Template transaction.
  TextColumn get type => textEnum<TxnType>()();
  IntColumn get amount => integer()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get toAmount => integer().nullable()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  // Schedule.
  TextColumn get frequency => textEnum<RecurrenceFrequency>()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get autoCreate => boolean().withDefault(const Constant(true))();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  IntColumn get remindDaysBefore => integer().nullable()();
}

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  RealColumn get rateToMain => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {currencyCode};
}

/// Simple key/value store for preferences and bookkeeping flags.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
