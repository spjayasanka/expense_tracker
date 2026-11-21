import 'package:drift/drift.dart';

import '../../domain/entities/entities.dart';
import 'default_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single on-device SQLite database. Nothing is ever synced anywhere.
@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Budgets, RecurringRules, ExchangeRates, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump this and add a step in [migration] whenever the schema changes.
  /// Older backups are migrated automatically when restored.
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaultCategories();
        },
        onUpgrade: (m, from, to) async {
          // Run each step in order so users can skip versions safely:
          // for (var v = from; v < to; v++) { switch (v) { case 1: ... } }
          // Example for a future v2:
          //   if (from < 2) await m.addColumn(accounts, accounts.someColumn);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> seedDefaultCategories() async {
    await batch((b) {
      var order = 0;
      for (final c in kDefaultExpenseCategories) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: c.name,
            type: CategoryType.expense,
            icon: c.icon,
            color: c.color,
            sortOrder: Value(order++),
          ),
        );
      }
      order = 0;
      for (final c in kDefaultIncomeCategories) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: c.name,
            type: CategoryType.income,
            icon: c.icon,
            color: c.color,
            sortOrder: Value(order++),
          ),
        );
      }
    });
  }

  /// Wipes every table and re-seeds default categories.
  Future<void> deleteAllData() async {
    // Children first so foreign keys stay satisfied (PRAGMA foreign_keys
    // cannot be toggled inside a transaction).
    await transaction(() async {
      for (final t in <TableInfo>[transactions, recurringRules, budgets, accounts, categories, exchangeRates, settings]) {
        await delete(t).go();
      }
      await customStatement('DELETE FROM sqlite_sequence');
      await seedDefaultCategories();
    });
  }
}
