import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../db/app_database.dart';

/// Result of inspecting a backup file before restoring it.
class BackupInfo {
  const BackupInfo({
    required this.schemaVersion,
    required this.accounts,
    required this.transactions,
    required this.categories,
  });

  final int schemaVersion;
  final int accounts;
  final int transactions;
  final int categories;
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Creates and restores single-file backups of the whole database.
/// Everything happens on the device; the user picks where files go.
class BackupService {
  const BackupService();

  static const fileExtension = 'llbackup';
  static const autoPrefix = 'pennyfold-auto-';

  /// Writes a consistent snapshot of [db] to [targetPath] using
  /// `VACUUM INTO` (safe while the database is open).
  Future<File> snapshot(AppDatabase db, String targetPath) async {
    final f = File(targetPath);
    if (f.existsSync()) f.deleteSync();
    final escaped = targetPath.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped'");
    return f;
  }

  /// Snapshot as bytes (for the system "save file" dialog).
  Future<Uint8List> snapshotBytes(AppDatabase db, Directory tempDir) async {
    final path = p.join(tempDir.path, 'snapshot-${DateTime.now().microsecondsSinceEpoch}.db');
    final f = await snapshot(db, path);
    try {
      return await f.readAsBytes();
    } finally {
      if (f.existsSync()) f.deleteSync();
    }
  }

  static String backupFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'pennyfold-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.$fileExtension';
  }

  /// Validates that [path] is a Pennyfold database this app can open.
  BackupInfo inspect(String path) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 100) {
      throw BackupException('not_a_backup');
    }
    final header = file.openSync()..setPositionSync(0);
    final magic = String.fromCharCodes(header.readSync(15));
    header.closeSync();
    if (magic != 'SQLite format 3') throw BackupException('not_a_backup');

    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final integrity = db.select('PRAGMA quick_check').first.values.first;
      if (integrity != 'ok') throw BackupException('corrupted');
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      const required = {'accounts', 'categories', 'transactions', 'settings'};
      if (!tables.containsAll(required)) throw BackupException('not_a_backup');
      final version = db.select('PRAGMA user_version').first.values.first as int;
      if (version > AppDatabase.currentSchemaVersion) throw BackupException('newer_version');
      int count(String table) =>
          db.select('SELECT COUNT(*) AS c FROM $table').first['c'] as int;
      return BackupInfo(
        schemaVersion: version,
        accounts: count('accounts'),
        transactions: count('transactions'),
        categories: count('categories'),
      );
    } on SqliteException {
      throw BackupException('corrupted');
    } finally {
      db.close();
    }
  }

  /// Replaces the database file at [dbPath] with [sourcePath].
  /// The caller must close the open database first and reopen it after.
  /// Older schemas are migrated by drift when the database is reopened.
  Future<void> replaceDatabaseFile({required String sourcePath, required String dbPath}) async {
    // Copy next to the live file first: if this fails (disk full, app killed)
    // the current database is untouched.
    final tmp = '$dbPath.restoring';
    await File(sourcePath).copy(tmp);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$dbPath$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    // Same-directory rename replaces the file atomically.
    await File(tmp).rename(dbPath);
  }

  /// Creates an automatic backup in [dir] and keeps only the newest [keep].
  Future<File> autoBackup(AppDatabase db, Directory dir, {required int keep, DateTime? now}) async {
    final ts = now ?? DateTime.now();
    final name = '$autoPrefix${backupFileName(ts).substring('pennyfold-'.length)}';
    final f = await snapshot(db, p.join(dir.path, name));
    await prune(dir, keep: keep);
    return f;
  }

  List<File> listAutoBackups(Directory dir) {
    if (!dir.existsSync()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(autoPrefix))
        .toList()
      ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  Future<void> prune(Directory dir, {required int keep}) async {
    final files = listAutoBackups(dir);
    for (final f in files.skip(keep)) {
      if (f.existsSync()) await f.delete();
    }
  }
}
