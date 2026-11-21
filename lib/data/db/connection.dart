import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const kDatabaseFileName = 'pennyfold.sqlite';

/// Absolute path of the on-device database file (inside the app's private
/// support directory; never synced).
Future<String> databaseFilePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, kDatabaseFileName);
}

/// Directory for automatic local backups.
Future<Directory> autoBackupDirectory() async {
  final dir = await getApplicationSupportDirectory();
  final d = Directory(p.join(dir.path, 'backups'));
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

QueryExecutor openDatabaseExecutor() => driftDatabase(
      name: 'pennyfold',
      native: const DriftNativeOptions(databasePath: databaseFilePath),
    );
