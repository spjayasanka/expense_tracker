import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/date_range.dart';
import '../../../data/db/connection.dart';
import '../../../data/services/backup_service.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/repositories/repositories.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../startup.dart';
import '../../widgets/common.dart';
import '../../widgets/formatters.dart';
import '../../widgets/period_bar.dart';
import '../lock/app_lock.dart';
import 'import_screen.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  List<File> _autoBackups = const [];

  @override
  void initState() {
    super.initState();
    _loadAutoBackups();
  }

  Future<void> _loadAutoBackups() async {
    final dir = await autoBackupDirectory();
    if (mounted) setState(() => _autoBackups = ref.read(backupServiceProvider).listAutoBackups(dir));
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.operationFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBytes(String name, Uint8List bytes, String mime) async {
    ref.read(lockProvider.notifier).suppressNextLock();
    final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
    if (!mounted) return;
    showSnack(context, uri == null ? context.l10n.saveCancelled : context.l10n.savedFile(name));
  }

  Future<void> _createBackup() => _guard(() async {
        final bytes = await ref
            .read(backupServiceProvider)
            .snapshotBytes(ref.read(databaseProvider), await getTemporaryDirectory());
        await _saveBytes(BackupService.backupFileName(DateTime.now()), bytes, 'application/octet-stream');
      });

  Future<void> _restoreFromPicker() => _guard(() async {
        ref.read(lockProvider.notifier).suppressNextLock();
        final files = await FilePicker.pickFiles(type: FileType.any);
        if (files.isEmpty) return;
        final bytes = await files.first.readAsBytes();
        final tmp = File(p.join((await getTemporaryDirectory()).path, 'restore-candidate.db'));
        await tmp.writeAsBytes(bytes, flush: true);
        await _restoreFrom(tmp.path);
        if (tmp.existsSync()) await tmp.delete();
      });

  Future<void> _restoreFrom(String path) async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);
    BackupInfo info;
    try {
      info = service.inspect(path);
    } on BackupException catch (e) {
      if (mounted) {
        showSnack(context, switch (e.message) {
          'newer_version' => l10n.backupNewerVersion,
          'corrupted' => l10n.backupCorrupted,
          _ => l10n.notABackup,
        });
      }
      return;
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: l10n.restoreBackupTitle,
      message: l10n.restoreBackupMessage(info.accounts, info.transactions),
      confirmLabel: l10n.restore,
      destructive: true,
    );
    if (!ok) return;
    // Safety net: keep a copy of the current data before overwriting it.
    final dir = await autoBackupDirectory();
    await service.snapshot(
      ref.read(databaseProvider),
      p.join(dir.path, 'pennyfold-before-restore.${BackupService.fileExtension}'),
    );
    final dbPath = await databaseFilePath();
    await ref
        .read(databaseProvider.notifier)
        .reopenAfter(() => service.replaceDatabaseFile(sourcePath: path, dbPath: dbPath));
    if (!mounted) return;
    await refreshRecurringState(ref, l10n);
    if (mounted) showSnack(context, l10n.restoreDone);
  }

  Future<void> _backupNow() => _guard(() async {
        final settings = ref.read(settingsProvider);
        final dir = await autoBackupDirectory();
        await ref
            .read(backupServiceProvider)
            .autoBackup(ref.read(databaseProvider), dir, keep: settings.autoBackupKeep);
        await ref.read(settingsRepoProvider).save(settings.copyWith(lastAutoBackup: () => DateTime.now()));
        await _loadAutoBackups();
      });

  Future<void> _export({required bool xlsx}) async {
    final l10n = context.l10n;
    final range = await _chooseExportRange();
    if (range == null || !mounted) return;
    await _guard(() async {
      final txns = await ref
          .read(transactionRepoProvider)
          .query(TxnFilter(range: range.$2));
      if (txns.isEmpty) {
        if (mounted) showSnack(context, l10n.nothingToExport);
        return;
      }
      final accounts = ref.read(accountsByIdProvider);
      final cats = ref.read(categoriesByIdProvider);
      final export = ref.read(exportServiceProvider);
      final stamp = BackupService.backupFileName(DateTime.now()).split('.').first.replaceFirst('pennyfold-', '');
      if (xlsx) {
        await _saveBytes('pennyfold-transactions-$stamp.xlsx', export.toXlsx(txns, accounts, cats),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      } else {
        await _saveBytes('pennyfold-transactions-$stamp.csv', export.toCsv(txns, accounts, cats), 'text/csv');
      }
    });
  }

  /// Returns (label, range) where a null range means all time.
  Future<(String, DateRange?)?> _chooseExportRange() async {
    final l10n = context.l10n;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.exportRange),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'all'), child: Text(l10n.allTime)),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'month'), child: Text(l10n.thisMonth)),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'year'), child: Text(l10n.thisYear)),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'custom'), child: Text(l10n.customRange)),
        ],
      ),
    );
    if (choice == null || !mounted) return null;
    final prefs = ref.read(settingsProvider).calendar;
    final now = DateTime.now();
    return switch (choice) {
      'all' => (choice, null),
      'month' => (choice, periodContaining(PeriodType.month, now, prefs)),
      'year' => (choice, periodContaining(PeriodType.year, now, prefs)),
      _ => await pickCustomRange(context, null).then((r) => r == null ? null : (choice, r)),
    };
  }

  Future<void> _import() => _guard(() async {
        ref.read(lockProvider.notifier).suppressNextLock();
        final files = await FilePicker.pickFiles(type: FileType.any);
        if (files.isEmpty || !mounted) return;
        final bytes = await files.first.readAsBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        final grid = ref.read(csvImporterProvider).decode(text);
        if (!mounted) return;
        if (grid.isEmpty) {
          showSnack(context, context.l10n.importEmpty);
          return;
        }
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportScreen(grid: grid)));
      });

  Future<void> _deleteAll() async {
    final l10n = context.l10n;
    final confirmWord = l10n.deleteConfirmWord;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.deleteAllDataTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteAllDataMessage),
              const SizedBox(height: 12),
              Text(l10n.typeToConfirm(confirmWord)),
              TextField(controller: controller, autofocus: true, onChanged: (_) => setLocal(() {})),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: controller.text.trim().toUpperCase() == confirmWord.toUpperCase()
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(l10n.deleteEverything),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _guard(() async {
      final rules = await ref.read(recurringRepoProvider).getAll();
      for (final r in rules) {
        await ref.read(notificationServiceProvider).cancelReminder(r.id);
      }
      await ref.read(databaseProvider).deleteAllData();
    });
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = ref.fmt(context);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupAndData)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.backupIntro, style: Theme.of(context).textTheme.bodyMedium),
            ),
            SectionHeader(l10n.backup),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.createBackup),
              subtitle: Text(l10n.createBackupHelp),
              onTap: _createBackup,
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(l10n.restoreBackup),
              subtitle: Text(l10n.restoreBackupHelp),
              onTap: _restoreFromPicker,
            ),
            SectionHeader(l10n.autoBackup),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.autoBackup),
              trailing: DropdownButton<AutoBackupFrequency>(
                value: settings.autoBackup,
                onChanged: (v) => ref.read(settingsRepoProvider).save(settings.copyWith(autoBackup: v)),
                items: [
                  DropdownMenuItem(value: AutoBackupFrequency.off, child: Text(l10n.off)),
                  DropdownMenuItem(value: AutoBackupFrequency.daily, child: Text(l10n.daily)),
                  DropdownMenuItem(value: AutoBackupFrequency.weekly, child: Text(l10n.weekly)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: Text(l10n.keepBackups),
              trailing: DropdownButton<int>(
                value: settings.autoBackupKeep,
                onChanged: (v) async {
                  await ref.read(settingsRepoProvider).save(settings.copyWith(autoBackupKeep: v));
                  await ref.read(backupServiceProvider).prune(await autoBackupDirectory(), keep: v!);
                  await _loadAutoBackups();
                },
                items: [
                  for (final n in {1, 3, 5, 7, 10, 20, 30, settings.autoBackupKeep}.toList()..sort())
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(l10n.backupNow),
              subtitle: Text(settings.lastAutoBackup == null
                  ? l10n.neverBackedUp
                  : l10n.lastBackup(fmt.date(settings.lastAutoBackup!), fmt.time(settings.lastAutoBackup!))),
              onTap: _backupNow,
            ),
            for (final f in _autoBackups)
              ListTile(
                dense: true,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(p.basename(f.path)),
                subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(0)} KB'),
                trailing: PopupMenuButton<String>(
                  tooltip: l10n.moreOptions,
                  onSelected: (v) async {
                    if (v == 'restore') await _guard(() => _restoreFrom(f.path));
                    if (v == 'save') {
                      await _guard(() async => _saveBytes(
                          p.basename(f.path).replaceFirst('-auto', ''), await f.readAsBytes(), 'application/octet-stream'));
                    }
                    if (v == 'delete') {
                      await f.delete();
                      await _loadAutoBackups();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'restore', child: Text(l10n.restore)),
                    PopupMenuItem(value: 'save', child: Text(l10n.saveCopy)),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                  ],
                ),
              ),
            SectionHeader(l10n.exportImport),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: Text(l10n.exportCsv),
              onTap: () => _export(xlsx: false),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: Text(l10n.exportXlsx),
              onTap: () => _export(xlsx: true),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.importCsv),
              subtitle: Text(l10n.importCsvHelp),
              onTap: _import,
            ),
            SectionHeader(l10n.dangerZone),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text(l10n.deleteAllData, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: Text(l10n.deleteAllDataHelp),
              onTap: _deleteAll,
            ),
          ],
        ),
      ),
    );
  }
}
