import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/export_import_service.dart';
import '../../l10n.dart';
import '../../providers/providers.dart';
import '../../widgets/common.dart';

/// Column-mapping step for CSV import.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.grid});
  final List<List<String>> grid;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _hasHeader = true;
  int? _date;
  int? _amount;
  int? _type;
  int? _category;
  int? _note;
  int? _account;
  String _dateFormat = kImportDateFormats.first;
  AmountSignMode _sign = AmountSignMode.signed;
  int? _defaultAccount;
  bool _busy = false;

  int get _columns => widget.grid.fold(0, (m, r) => r.length > m ? r.length : m);

  @override
  void initState() {
    super.initState();
    final guess = ref.read(csvImporterProvider).guessColumns(widget.grid.first);
    _date = guess['date'];
    _amount = guess['amount'];
    _type = guess['type'];
    _category = guess['category'];
    _note = guess['note'];
    _account = guess['account'];
    _hasHeader = guess.isNotEmpty;
    _defaultAccount = ref.read(settingsProvider).defaultAccountId ?? ref.read(activeAccountsProvider).firstOrNull?.id;
    _dateFormat = _guessDateFormat();
  }

  String _guessDateFormat() {
    if (_date == null) return _dateFormat;
    final importer = ref.read(csvImporterProvider);
    final samples = widget.grid.skip(1).take(20).map((r) => _date! < r.length ? r[_date!] : '').toList();
    for (final f in kImportDateFormats) {
      if (samples.where((s) => s.isNotEmpty).every((s) => importer.parseDate(s, f) != null)) return f;
    }
    return _dateFormat;
  }

  String _colName(int i) {
    final h = widget.grid.first;
    return _hasHeader && i < h.length && h[i].isNotEmpty ? h[i] : context.l10n.columnN(i + 1);
  }

  ImportMapping? get _mapping => _date == null || _amount == null || _defaultAccount == null
      ? null
      : ImportMapping(
          dateColumn: _date!,
          amountColumn: _amount!,
          typeColumn: _type,
          categoryColumn: _category,
          noteColumn: _note,
          accountColumn: _account,
          dateFormat: _dateFormat,
          hasHeader: _hasHeader,
          signMode: _sign,
          defaultAccountId: _defaultAccount!,
        );

  Future<void> _import(ImportParseResult result) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final n = await ref.read(csvImporterProvider).commit(
            result.rows,
            transactions: ref.read(transactionRepoProvider),
            categories: ref.read(categoryRepoProvider),
            accountsById: ref.read(accountsByIdProvider),
          );
      if (!mounted) return;
      showSnack(context, l10n.importDone(n));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, l10n.operationFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = ref.watch(activeAccountsProvider);
    final mapping = _mapping;
    final result = mapping == null
        ? null
        : ref.read(csvImporterProvider).parse(widget.grid, mapping, ref.watch(accountsByIdProvider));

    Widget columnPicker(String label, int? value, ValueChanged<int?> onChanged, {bool required = false}) =>
        DropdownButtonFormField<int>(
          initialValue: value ?? -1,
          isExpanded: true,
          decoration: InputDecoration(labelText: required ? '$label *' : label),
          items: [
            if (!required || value == null) DropdownMenuItem(value: -1, child: Text(l10n.notMapped)),
            for (var i = 0; i < _columns; i++) DropdownMenuItem(value: i, child: Text(_colName(i))),
          ],
          onChanged: (v) => setState(() => onChanged(v == null || v < 0 ? null : v)),
        );

    final preview = widget.grid.skip(_hasHeader ? 1 : 0).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importCsv)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text(l10n.importPreview, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [for (var i = 0; i < _columns; i++) DataColumn(label: Text(_colName(i)))],
                rows: [
                  for (final r in preview)
                    DataRow(cells: [
                      for (var i = 0; i < _columns; i++) DataCell(Text(i < r.length ? r[i] : '')),
                    ]),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.firstRowIsHeader),
              value: _hasHeader,
              onChanged: (v) => setState(() => _hasHeader = v),
            ),
            SectionHeader(l10n.columnMapping),
            columnPicker(l10n.date, _date, (v) {
              _date = v;
              _dateFormat = _guessDateFormat();
            }, required: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Re-key so a re-guessed format is reflected in the field.
              key: ValueKey('date-format-$_dateFormat'),
              initialValue: _dateFormat,
              decoration: InputDecoration(labelText: l10n.dateFormat),
              items: [for (final f in kImportDateFormats) DropdownMenuItem(value: f, child: Text(f))],
              onChanged: (v) => setState(() => _dateFormat = v!),
            ),
            const SizedBox(height: 12),
            columnPicker(l10n.amount, _amount, (v) => _amount = v, required: true),
            const SizedBox(height: 12),
            columnPicker(l10n.type, _type, (v) => _type = v),
            const SizedBox(height: 12),
            if (_type == null) ...[
              DropdownButtonFormField<AmountSignMode>(
                initialValue: _sign,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.amountMeaning),
                items: [
                  DropdownMenuItem(value: AmountSignMode.signed, child: Text(l10n.signedAmounts)),
                  DropdownMenuItem(value: AmountSignMode.allExpense, child: Text(l10n.allExpenses)),
                  DropdownMenuItem(value: AmountSignMode.allIncome, child: Text(l10n.allIncome)),
                ],
                onChanged: (v) => setState(() => _sign = v!),
              ),
              const SizedBox(height: 12),
            ],
            columnPicker(l10n.category, _category, (v) => _category = v),
            const SizedBox(height: 12),
            columnPicker(l10n.note, _note, (v) => _note = v),
            const SizedBox(height: 12),
            columnPicker(l10n.account, _account, (v) => _account = v),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _defaultAccount,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.defaultImportAccount),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.currency})'))],
              onChanged: (v) => setState(() => _defaultAccount = v),
            ),
            const SizedBox(height: 24),
            if (result != null) ...[
              Text(l10n.importSummary(result.rows.length, result.skippedLines.length)),
              if (result.skippedLines.isNotEmpty)
                Text(
                  l10n.skippedLines(result.skippedLines.take(10).join(', ')),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: result == null || result.rows.isEmpty ? null : () => _import(result),
              icon: const Icon(Icons.download_done),
              label: Text(l10n.importNRows(result?.rows.length ?? 0)),
            ),
          ],
        ),
      ),
    );
  }
}
