import '../../core/utils/date_range.dart';
import '../entities/app_settings.dart';
import '../entities/entities.dart';
import '../services/balance_calculator.dart';

/// Filter for listing/searching transactions.
class TxnFilter {
  const TxnFilter({
    this.range,
    this.accountIds,
    this.categoryIds,
    this.types,
    this.search,
    this.limit,
  });

  final DateRange? range;

  /// Matches transactions whose source or destination is in this set.
  final Set<int>? accountIds;
  final Set<int>? categoryIds;
  final Set<TxnType>? types;

  /// Free text: matches note, category name, or exact amount.
  final String? search;
  final int? limit;

  TxnFilter copyWith({
    DateRange? Function()? range,
    Set<int>? Function()? accountIds,
    Set<int>? Function()? categoryIds,
    Set<TxnType>? Function()? types,
    String? Function()? search,
  }) =>
      TxnFilter(
        range: range != null ? range() : this.range,
        accountIds: accountIds != null ? accountIds() : this.accountIds,
        categoryIds: categoryIds != null ? categoryIds() : this.categoryIds,
        types: types != null ? types() : this.types,
        search: search != null ? search() : this.search,
        limit: limit,
      );

  bool get hasNarrowing =>
      (accountIds?.isNotEmpty ?? false) ||
      (categoryIds?.isNotEmpty ?? false) ||
      (types?.isNotEmpty ?? false);

  @override
  bool operator ==(Object other) =>
      other is TxnFilter &&
      other.range == range &&
      _setEq(other.accountIds, accountIds) &&
      _setEq(other.categoryIds, categoryIds) &&
      _setEq(other.types, types) &&
      other.search == search &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        range,
        accountIds == null ? null : Object.hashAllUnordered(accountIds!),
        categoryIds == null ? null : Object.hashAllUnordered(categoryIds!),
        types == null ? null : Object.hashAllUnordered(types!),
        search,
        limit,
      );
}

bool _setEq<T>(Set<T>? a, Set<T>? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length && a.containsAll(b);
}

/// Sum of income/expense amounts grouped by type, category and currency.
class CategoryTotal {
  const CategoryTotal({
    required this.type,
    required this.categoryId,
    required this.currency,
    required this.amount,
    required this.count,
  });

  final TxnType type;
  final int? categoryId;
  final String currency;
  final int amount;
  final int count;
}

/// Flows for one account on one calendar day.
class AccountDayFlow {
  const AccountDayFlow(this.day, this.accountId, this.flows);
  final DateTime day;
  final int accountId;
  final AccountFlows flows;
}

abstract interface class AccountRepository {
  Stream<List<Account>> watchAll();
  Future<List<Account>> getAll();
  Future<Account?> getById(int id);
  Future<int> add(Account account);
  Future<void> update(Account account);

  /// Deletes the account together with its transactions and recurring rules.
  Future<void> delete(int id);
  Future<void> reorder(List<int> orderedIds);
  Future<int> transactionCount(int accountId);

  /// All-time flows per account (for balances).
  Stream<Map<int, AccountFlows>> watchFlows();

  /// Flows per account within [range] (or all time when null).
  Future<Map<int, AccountFlows>> flows({DateRange? range});

  /// Daily flows per account within [range].
  Future<List<AccountDayFlow>> dailyFlows(DateRange range);
}

abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll();
  Future<List<Category>> getAll();
  Future<int> add(Category category);
  Future<void> update(Category category);
  Future<void> reorder(List<int> orderedIds);
  Future<int> transactionCount(int categoryId);

  /// Moves every transaction, budget and recurring rule from [fromId] into
  /// [intoId] and deletes [fromId].
  Future<void> merge({required int fromId, required int intoId});

  /// Deletes a category and every transaction in it.
  Future<void> deleteWithTransactions(int id);

  /// Finds a category by name (case-insensitive) or creates it.
  Future<int> findOrCreate(String name, CategoryType type);
}

abstract interface class TransactionRepository {
  Stream<List<Txn>> watch(TxnFilter filter);
  Future<List<Txn>> query(TxnFilter filter);
  Future<Txn?> getById(int id);
  Future<int> add(Txn txn);
  Future<void> addAll(List<Txn> txns);
  Future<void> update(Txn txn);

  /// Deletes and returns the deleted transaction (for undo).
  Future<Txn?> delete(int id);

  /// Re-inserts a previously deleted transaction with its original id.
  Future<void> restore(Txn txn);

  Future<int> count();

  /// Income/expense totals grouped by category & currency.
  Stream<List<CategoryTotal>> watchCategoryTotals(DateRange range, {Set<int>? accountIds});
  Future<List<CategoryTotal>> categoryTotals(DateRange range, {Set<int>? accountIds});

  /// Expense sums grouped by currency (for budgets).
  Future<Map<String, int>> expenseByCurrency(DateRange range, {int? categoryId});

  /// Date of the earliest transaction, if any.
  Future<DateTime?> firstDate();
}

abstract interface class BudgetRepository {
  Stream<List<Budget>> watchAll();
  Future<List<Budget>> getAll();
  Future<int> add(Budget budget);
  Future<void> update(Budget budget);
  Future<void> delete(int id);
}

abstract interface class RecurringRepository {
  Stream<List<RecurringRule>> watchAll();
  Future<List<RecurringRule>> getAll();
  Future<RecurringRule?> getById(int id);
  Future<int> add(RecurringRule rule);
  Future<void> update(RecurringRule rule);
  Future<void> delete(int id);
}

abstract interface class ExchangeRateRepository {
  Stream<List<ExchangeRate>> watchAll();
  Future<List<ExchangeRate>> getAll();
  Future<void> upsert(ExchangeRate rate);
  Future<void> delete(String currencyCode);
  Future<void> clear();
}

abstract interface class SettingsRepository {
  Stream<AppSettings> watch();
  Future<AppSettings> get();
  Future<void> save(AppSettings settings);

  /// Free-form flags (e.g. which budget alerts were already sent).
  Future<String?> getValue(String key);
  Future<void> setValue(String key, String? value);
}
