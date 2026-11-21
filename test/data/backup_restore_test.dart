import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/data/db/app_database.dart';
import 'package:pennyfold/data/services/backup_service.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../helpers/test_db.dart';

void main() {
  late Directory dir;
  const service = BackupService();

  setUp(() => dir = Directory.systemTemp.createTempSync('pennyfold_backup_test'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AppDatabase openFile(String path) => AppDatabase(NativeDatabase(File(path)));

  test('backup → wipe → restore brings every row back', () async {
    final dbPath = p.join(dir.path, 'live.sqlite');
    var db = openFile(dbPath);
    var r = Repos(db);
    final cash = await r.account('Cash', initial: 5000);
    final euro = await r.account('Euro', currency: 'EUR');
    final food = (await r.categories.getAll()).firstWhere((c) => c.name == 'Food').id;
    await r.txn(type: TxnType.expense, amount: 1234, accountId: cash, categoryId: food, note: 'Lunch ☕');
    await r.txn(type: TxnType.transfer, amount: 1000, accountId: cash, toAccountId: euro, toAmount: 900);
    await r.rates.upsert(ExchangeRate(currencyCode: 'EUR', rateToMain: 1.1, updatedAt: DateTime(2026)));
    await r.settings.setValue('mainCurrency', 'USD');

    // Snapshot while the database is open.
    final backupPath = p.join(dir.path, BackupService.backupFileName(DateTime(2026, 11, 9, 8, 5)));
    expect(p.basename(backupPath), 'pennyfold-20261109-0805.llbackup');
    await service.snapshot(db, backupPath);

    final info = service.inspect(backupPath);
    expect(info.accounts, 2);
    expect(info.transactions, 2);
    expect(info.schemaVersion, AppDatabase.currentSchemaVersion);

    // Lose everything.
    await db.deleteAllData();
    expect(await r.transactions.count(), 0);
    await db.close();

    // Restore: replace file and reopen.
    await service.replaceDatabaseFile(sourcePath: backupPath, dbPath: dbPath);
    db = openFile(dbPath);
    r = Repos(db);
    final txns = await r.transactions.query(const TxnFilter());
    expect(txns, hasLength(2));
    expect(txns.map((t) => t.note), contains('Lunch ☕'));
    expect((await r.accounts.getAll()).map((a) => a.name), ['Cash', 'Euro']);
    expect((await r.rates.getAll()).single.rateToMain, 1.1);
    expect(await r.settings.getValue('mainCurrency'), 'USD');
    final flows = await r.accounts.flows();
    expect(flows[euro]!.transferIn, 900);
    await db.close();
  });

  test('rejects files that are not Pennyfold backups', () async {
    final junk = File(p.join(dir.path, 'junk.bin'))..writeAsStringSync('hello' * 100);
    expect(() => service.inspect(junk.path), throwsA(isA<BackupException>()));

    final other = p.join(dir.path, 'other.sqlite');
    final raw = sqlite3.open(other)..execute('CREATE TABLE notes(id INTEGER, body TEXT)');
    raw.execute("INSERT INTO notes VALUES (1, '${'x' * 200}')");
    raw.close();
    expect(
      () => service.inspect(other),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', 'not_a_backup')),
    );
  });

  test('rejects backups from a newer schema version', () async {
    final dbPath = p.join(dir.path, 'live.sqlite');
    final db = openFile(dbPath);
    await Repos(db).account('Cash');
    final backupPath = p.join(dir.path, 'b.llbackup');
    await service.snapshot(db, backupPath);
    await db.close();
    final raw = sqlite3.open(backupPath)..execute('PRAGMA user_version = 999');
    raw.close();
    expect(
      () => service.inspect(backupPath),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', 'newer_version')),
    );
  });

  test('automatic backups keep only the newest N', () async {
    final db = newTestDb();
    await Repos(db).account('Cash');
    final autoDir = Directory(p.join(dir.path, 'auto'))..createSync();
    for (var i = 0; i < 5; i++) {
      await service.autoBackup(db, autoDir, keep: 3, now: DateTime(2026, 1, 1 + i, 9));
    }
    final files = service.listAutoBackups(autoDir);
    expect(files, hasLength(3));
    expect(p.basename(files.first.path), contains('20260105'));
    expect(p.basename(files.last.path), contains('20260103'));
    // Each one is a valid, restorable backup.
    expect(service.inspect(files.first.path).accounts, 1);
    await db.close();
  });
}
