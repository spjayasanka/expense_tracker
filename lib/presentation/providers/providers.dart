import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_range.dart';
import '../../data/db/app_database.dart';
import '../../data/db/connection.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/services/app_lock_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/export_import_service.dart';
import '../../data/services/home_widget_service.dart';
import '../../data/services/notification_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/balance_calculator.dart';
import '../../domain/services/budget_calculator.dart';
import '../../domain/services/currency_converter.dart';
import '../../domain/usecases/budget_service.dart';
import '../../domain/usecases/recurring_generator.dart';

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// Owns the open database. Restoring a backup swaps the instance, which
/// rebuilds every dependent provider automatically.
class DatabaseController extends Notifier<AppDatabase> {
  DatabaseController([this._factory]);

  final AppDatabase Function()? _factory;

  AppDatabase _open() => _factory?.call() ?? AppDatabase(openDatabaseExecutor());

  @override
  AppDatabase build() {
    final db = _open();
    ref.onDispose(db.close);
    return db;
  }

  /// Closes the database, runs [fileOperation] (e.g. replace the file),
  /// then reopens it.
  Future<void> reopenAfter(Future<void> Function() fileOperation) async {
    await state.close();
    try {
      await fileOperation();
    } finally {
      state = _open();
    }
  }
}

final databaseProvider = NotifierProvider<DatabaseController, AppDatabase>(DatabaseController.new);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final accountRepoProvider =
    Provider<AccountRepository>((ref) => DriftAccountRepository(ref.watch(databaseProvider)));
final categoryRepoProvider =
    Provider<CategoryRepository>((ref) => DriftCategoryRepository(ref.watch(databaseProvider)));
final transactionRepoProvider = Provider<TransactionRepository>(
    (ref) => DriftTransactionRepository(ref.watch(databaseProvider)));
final budgetRepoProvider =
    Provider<BudgetRepository>((ref) => DriftBudgetRepository(ref.watch(databaseProvider)));
final recurringRepoProvider =
    Provider<RecurringRepository>((ref) => DriftRecurringRepository(ref.watch(databaseProvider)));
final rateRepoProvider = Provider<ExchangeRateRepository>(
    (ref) => DriftExchangeRateRepository(ref.watch(databaseProvider)));
final settingsRepoProvider =
    Provider<SettingsRepository>((ref) => DriftSettingsRepository(ref.watch(databaseProvider)));

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
final backupServiceProvider = Provider<BackupService>((ref) => const BackupService());
final exportServiceProvider = Provider<ExportService>((ref) => const ExportService());
final csvImporterProvider = Provider<CsvImporter>((ref) => const CsvImporter());
final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) => const HomeWidgetService());

final recurringGeneratorProvider = Provider<RecurringGenerator>((ref) => RecurringGenerator(
      recurring: ref.watch(recurringRepoProvider),
      transactions: ref.watch(transactionRepoProvider),
      accounts: ref.watch(accountRepoProvider),
    ));

final budgetServiceProvider = Provider<BudgetService>((ref) => BudgetService(
      budgets: ref.watch(budgetRepoProvider),
      transactions: ref.watch(transactionRepoProvider),
      settings: ref.watch(settingsRepoProvider),
    ));

// ---------------------------------------------------------------------------
// Reactive data
// ---------------------------------------------------------------------------

final settingsStreamProvider =
    StreamProvider<AppSettings>((ref) => ref.watch(settingsRepoProvider).watch());

/// Current settings (defaults until the first database read completes).
final settingsProvider = Provider<AppSettings>(
    (ref) => ref.watch(settingsStreamProvider).value ?? const AppSettings());

final accountsStreamProvider =
    StreamProvider<List<Account>>((ref) => ref.watch(accountRepoProvider).watchAll());

final accountsProvider =
    Provider<List<Account>>((ref) => ref.watch(accountsStreamProvider).value ?? const []);

final accountsByIdProvider =
    Provider<Map<int, Account>>((ref) => {for (final a in ref.watch(accountsProvider)) a.id: a});

final activeAccountsProvider = Provider<List<Account>>(
    (ref) => ref.watch(accountsProvider).where((a) => !a.isArchived).toList());

final categoriesStreamProvider =
    StreamProvider<List<Category>>((ref) => ref.watch(categoryRepoProvider).watchAll());

final categoriesProvider =
    Provider<List<Category>>((ref) => ref.watch(categoriesStreamProvider).value ?? const []);

final categoriesByIdProvider = Provider<Map<int, Category>>(
    (ref) => {for (final c in ref.watch(categoriesProvider)) c.id: c});

final ratesStreamProvider =
    StreamProvider<List<ExchangeRate>>((ref) => ref.watch(rateRepoProvider).watchAll());

final converterProvider = Provider<CurrencyConverter>((ref) => CurrencyConverter.fromRates(
      ref.watch(settingsProvider).mainCurrency,
      ref.watch(ratesStreamProvider).value ?? const [],
    ));

final budgetsStreamProvider =
    StreamProvider<List<Budget>>((ref) => ref.watch(budgetRepoProvider).watchAll());

final recurringStreamProvider =
    StreamProvider<List<RecurringRule>>((ref) => ref.watch(recurringRepoProvider).watchAll());

final accountFlowsProvider =
    StreamProvider<Map<int, AccountFlows>>((ref) => ref.watch(accountRepoProvider).watchFlows());

final balancesProvider = Provider<List<AccountBalance>>((ref) => const BalanceCalculator().balances(
      ref.watch(accountsProvider),
      ref.watch(accountFlowsProvider).value ?? const {},
    ));

/// Combined balance of included, non-archived accounts in main currency.
final totalBalanceProvider = Provider<int>((ref) => const BalanceCalculator()
    .totalBalance(ref.watch(balancesProvider), ref.watch(converterProvider)));

/// Currencies in use that have no exchange rate yet.
final missingRatesProvider = Provider<Set<String>>((ref) {
  final conv = ref.watch(converterProvider);
  return conv.missingRates(ref.watch(activeAccountsProvider).map((a) => a.currency));
});

final transactionsProvider = StreamProvider.autoDispose.family<List<Txn>, TxnFilter>(
    (ref, filter) => ref.watch(transactionRepoProvider).watch(filter));

// ---------------------------------------------------------------------------
// Period statistics
// ---------------------------------------------------------------------------

/// Income/expense totals for a period, converted to the main currency.
class PeriodStats {
  const PeriodStats({
    required this.income,
    required this.expense,
    required this.expenseByCategory,
    required this.incomeByCategory,
  });

  final int income;
  final int expense;
  final Map<int?, int> expenseByCategory;
  final Map<int?, int> incomeByCategory;

  int get balance => income - expense;
  static const empty = PeriodStats(
    income: 0,
    expense: 0,
    expenseByCategory: {},
    incomeByCategory: {},
  );

  static PeriodStats fromTotals(List<CategoryTotal> totals, CurrencyConverter conv) {
    var income = 0, expense = 0;
    final exp = <int?, int>{}, inc = <int?, int>{};
    for (final t in totals) {
      final v = conv.toMain(t.amount, t.currency);
      if (t.type == TxnType.expense) {
        expense += v;
        exp[t.categoryId] = (exp[t.categoryId] ?? 0) + v;
      } else if (t.type == TxnType.income) {
        income += v;
        inc[t.categoryId] = (inc[t.categoryId] ?? 0) + v;
      }
    }
    return PeriodStats(
      income: income,
      expense: expense,
      expenseByCategory: exp,
      incomeByCategory: inc,
    );
  }
}

typedef StatsQuery = ({DateRange range, int? accountId});

final _categoryTotalsProvider =
    StreamProvider.autoDispose.family<List<CategoryTotal>, StatsQuery>((ref, q) => ref
        .watch(transactionRepoProvider)
        .watchCategoryTotals(q.range, accountIds: q.accountId == null ? null : {q.accountId!}));

final periodStatsProvider = Provider.autoDispose.family<AsyncValue<PeriodStats>, StatsQuery>(
  (ref, q) => ref
      .watch(_categoryTotalsProvider(q))
      .whenData((totals) => PeriodStats.fromTotals(totals, ref.watch(converterProvider))),
);

// ---------------------------------------------------------------------------
// Home period selection
// ---------------------------------------------------------------------------

class HomePeriod {
  const HomePeriod({this.type = PeriodType.month, this.custom, this.accountId});

  final PeriodType type;
  final DateRange? custom;

  /// Null = all accounts.
  final int? accountId;

  bool get swipeable => type != PeriodType.all && type != PeriodType.custom;

  HomePeriod copyWith({PeriodType? type, DateRange? Function()? custom, int? Function()? accountId}) =>
      HomePeriod(
        type: type ?? this.type,
        custom: custom != null ? custom() : this.custom,
        accountId: accountId != null ? accountId() : this.accountId,
      );
}

class HomePeriodController extends Notifier<HomePeriod> {
  @override
  HomePeriod build() => const HomePeriod();

  void setType(PeriodType type) => state = state.copyWith(type: type);
  void setCustom(DateRange range) =>
      state = state.copyWith(type: PeriodType.custom, custom: () => range);
  void setAccount(int? id) => state = state.copyWith(accountId: () => id);
}

final homePeriodProvider =
    NotifierProvider<HomePeriodController, HomePeriod>(HomePeriodController.new);

/// Base range (offset 0) for the home period.
DateRange basePeriodRange(HomePeriod p, CalendarPrefs prefs, DateTime now) {
  if (p.type == PeriodType.custom && p.custom != null) return p.custom!;
  return periodContaining(p.type, now, prefs);
}

// ---------------------------------------------------------------------------
// Budgets
// ---------------------------------------------------------------------------

final budgetStatusesProvider = FutureProvider.autoDispose<List<BudgetStatus>>((ref) async {
  // Recompute whenever budgets, transactions (via flows) or rates change.
  ref.watch(budgetsStreamProvider);
  ref.watch(accountFlowsProvider);
  final settings = ref.watch(settingsProvider);
  return ref
      .watch(budgetServiceProvider)
      .allStatuses(DateTime.now(), settings.calendar, ref.watch(converterProvider));
});
