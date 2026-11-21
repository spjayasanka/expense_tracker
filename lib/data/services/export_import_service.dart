import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/money/currencies.dart';
import '../../core/money/money_format.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

/// Column headers used for export (and recognised on import).
const kExportHeaders = [
  'Date',
  'Type',
  'Amount',
  'Currency',
  'Account',
  'To account',
  'To amount',
  'Category',
  'Note',
];

/// Builds CSV / XLSX files from transactions entirely in memory.
class ExportService {
  const ExportService();

  List<List<Object?>> _rows(
    List<Txn> txns,
    Map<int, Account> accounts,
    Map<int, Category> categories,
  ) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return [
      for (final t in txns)
        [
          df.format(t.date),
          t.type.name,
          MoneyFormatter.toEditable(t.amount, currencyFor(t.currency).decimals),
          t.currency,
          _safe(accounts[t.accountId]?.name ?? ''),
          _safe(t.toAccountId == null ? '' : accounts[t.toAccountId]?.name ?? ''),
          t.toAmount == null || t.toAccountId == null
              ? ''
              : MoneyFormatter.toEditable(
                  t.toAmount!, currencyFor(accounts[t.toAccountId]?.currency ?? t.currency).decimals),
          _safe(t.categoryId == null ? '' : categories[t.categoryId]?.name ?? ''),
          _safe(t.note),
        ],
    ];
  }

  /// Spreadsheet apps run CSV cells starting with = + - @ as formulas
  /// (CSV injection). Prefix such free-text values with an apostrophe.
  static String _safe(String v) =>
      v.isNotEmpty && '=+-@\t\r'.contains(v[0]) ? "'$v" : v;

  Uint8List toCsv(List<Txn> txns, Map<int, Account> accounts, Map<int, Category> categories) {
    final text = Csv(addBom: true).encode([kExportHeaders, ..._rows(txns, accounts, categories)]);
    return Uint8List.fromList(utf8.encode(text));
  }

  Uint8List toXlsx(List<Txn> txns, Map<int, Account> accounts, Map<int, Category> categories) {
    final excel = Excel.createExcel();
    const sheetName = 'Transactions';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    for (final name in excel.tables.keys.toList()) {
      if (name != sheetName) excel.delete(name);
    }
    sheet.appendRow([for (final h in kExportHeaders) TextCellValue(h)]);
    for (final t in txns) {
      final dec = currencyFor(t.currency).decimals;
      sheet.appendRow([
        DateTimeCellValue(
          year: t.date.year,
          month: t.date.month,
          day: t.date.day,
          hour: t.date.hour,
          minute: t.date.minute,
        ),
        TextCellValue(t.type.name),
        DoubleCellValue(t.amount / pow10(dec)),
        TextCellValue(t.currency),
        TextCellValue(accounts[t.accountId]?.name ?? ''),
        TextCellValue(t.toAccountId == null ? '' : accounts[t.toAccountId]?.name ?? ''),
        t.toAmount == null || t.toAccountId == null
            ? TextCellValue('')
            : DoubleCellValue(t.toAmount! /
                pow10(currencyFor(accounts[t.toAccountId]?.currency ?? t.currency).decimals)),
        TextCellValue(t.categoryId == null ? '' : categories[t.categoryId]?.name ?? ''),
        TextCellValue(t.note),
      ]);
    }
    final bytes = excel.save();
    if (bytes == null) throw StateError('Could not create the spreadsheet');
    return Uint8List.fromList(bytes);
  }
}

// ---------------------------------------------------------------------------
// CSV import
// ---------------------------------------------------------------------------

enum AmountSignMode {
  /// Negative amounts are expenses, positive are income.
  signed,

  /// Every row is an expense (amount sign ignored).
  allExpense,

  /// Every row is income (amount sign ignored).
  allIncome,
}

/// Supported input date patterns for import.
const kImportDateFormats = [
  'yyyy-MM-dd',
  'dd/MM/yyyy',
  'MM/dd/yyyy',
  'dd.MM.yyyy',
  'dd-MM-yyyy',
  'yyyy/MM/dd',
];

class ImportMapping {
  const ImportMapping({
    required this.dateColumn,
    required this.amountColumn,
    this.typeColumn,
    this.categoryColumn,
    this.noteColumn,
    this.accountColumn,
    this.dateFormat = 'yyyy-MM-dd',
    this.hasHeader = true,
    this.signMode = AmountSignMode.signed,
    required this.defaultAccountId,
  });

  final int dateColumn;
  final int amountColumn;
  final int? typeColumn;
  final int? categoryColumn;
  final int? noteColumn;
  final int? accountColumn;
  final String dateFormat;
  final bool hasHeader;
  final AmountSignMode signMode;
  final int defaultAccountId;
}

/// A parsed, validated row ready to insert.
class ImportedRow {
  const ImportedRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryName,
    this.note = '',
  });

  final DateTime date;
  final TxnType type;
  final int amount;
  final int accountId;
  final String? categoryName;
  final String note;
}

class ImportParseResult {
  const ImportParseResult(this.rows, this.skippedLines);
  final List<ImportedRow> rows;

  /// 1-based line numbers that could not be parsed.
  final List<int> skippedLines;
}

class CsvImporter {
  const CsvImporter();

  /// Decodes CSV text (delimiter auto-detected) into a grid of strings.
  List<List<String>> decode(String text) {
    var t = text;
    if (t.startsWith('﻿')) t = t.substring(1);
    final rows = Csv().decode(t);
    return [
      for (final r in rows) [for (final c in r) c?.toString().trim() ?? ''],
    ];
  }

  /// Best-effort guess of the column mapping from header names.
  Map<String, int> guessColumns(List<String> header) {
    final lower = [for (final h in header) h.toLowerCase().trim()];
    int? find(List<String> keys) {
      for (var i = 0; i < lower.length; i++) {
        if (keys.any((k) => lower[i] == k || lower[i].contains(k))) return i;
      }
      return null;
    }

    return {
      'date': ?find(['date', 'day', 'time']),
      'amount': ?find(['amount', 'sum', 'value', 'price']),
      'type': ?find(['type', 'kind']),
      'category': ?find(['category', 'cat']),
      'note': ?find(['note', 'description', 'memo', 'comment', 'payee']),
      'account': ?find(['account', 'wallet']),
    };
  }

  DateTime? parseDate(String value, String pattern) {
    final v = value.trim();
    if (v.isEmpty) return null;
    try {
      // Accept an optional time part after the date.
      final datePart = v.split(RegExp(r'[ T]')).first;
      final d = DateFormat(pattern).parseStrict(datePart);
      final iso = DateTime.tryParse(v);
      if (iso != null && iso.year == d.year && iso.month == d.month && iso.day == d.day) {
        return iso;
      }
      return DateTime(d.year, d.month, d.day, 12);
    } catch (_) {
      // DateTime.tryParse rolls invalid dates over (2024-02-30 → Mar 1);
      // only accept it when the date part round-trips exactly.
      final iso = DateTime.tryParse(v);
      if (iso == null) return null;
      final ymd = DateFormat('yyyy-MM-dd').format(iso);
      return v.startsWith(ymd) ? iso : null;
    }
  }

  ImportParseResult parse(
    List<List<String>> grid,
    ImportMapping m,
    Map<int, Account> accountsById,
  ) {
    final byName = {
      for (final a in accountsById.values) a.name.toLowerCase().trim(): a,
    };
    final rows = <ImportedRow>[];
    final skipped = <int>[];
    final first = m.hasHeader ? 1 : 0;
    String cleanAmount(String v) => v.replaceAll(RegExp(r'[^\d,.\-−()]'), '');
    final decimalSep = detectDecimalSeparator([
      for (var i = first; i < grid.length; i++)
        if (m.amountColumn < grid[i].length) cleanAmount(grid[i][m.amountColumn]),
    ]);
    for (var i = first; i < grid.length; i++) {
      final r = grid[i];
      String cell(int? c) => c != null && c < r.length ? r[c] : '';
      if (r.every((c) => c.isEmpty)) continue;

      var account = accountsById[m.defaultAccountId];
      final accountName = cell(m.accountColumn).toLowerCase().trim();
      if (accountName.isNotEmpty) {
        // A named account that doesn't exist (e.g. renamed) must not silently
        // land in the default account, possibly in another currency.
        account = byName[accountName];
      }
      if (account == null) {
        skipped.add(i + 1);
        continue;
      }
      final date = parseDate(cell(m.dateColumn), m.dateFormat);
      final rawAmount = parseMinorUnits(
        cleanAmount(cell(m.amountColumn)),
        currencyFor(account.currency).decimals,
        decimalSeparator: decimalSep,
      );
      if (date == null || rawAmount == null || rawAmount == 0) {
        skipped.add(i + 1);
        continue;
      }
      TxnType type;
      final typeText = cell(m.typeColumn).toLowerCase();
      if (typeText.startsWith('inc') || typeText == 'credit' || typeText == '+') {
        type = TxnType.income;
      } else if (typeText.startsWith('exp') || typeText == 'debit' || typeText == '-') {
        type = TxnType.expense;
      } else if (typeText.startsWith('trans')) {
        // Transfers need two accounts; not supported by CSV import.
        skipped.add(i + 1);
        continue;
      } else {
        type = switch (m.signMode) {
          AmountSignMode.signed => rawAmount < 0 ? TxnType.expense : TxnType.income,
          AmountSignMode.allExpense => TxnType.expense,
          AmountSignMode.allIncome => TxnType.income,
        };
      }
      final category = _unescape(cell(m.categoryColumn));
      rows.add(ImportedRow(
        date: date,
        type: type,
        amount: rawAmount.abs(),
        accountId: account.id,
        categoryName: category.isEmpty ? null : category,
        note: _unescape(cell(m.noteColumn)),
      ));
    }
    return ImportParseResult(rows, skipped);
  }

  /// Reverses the export's CSV-injection escaping ("'=foo" → "=foo").
  static String _unescape(String v) =>
      v.length > 1 && v[0] == "'" && '=+-@\t\r'.contains(v[1]) ? v.substring(1) : v;

  /// Inserts parsed rows, creating missing categories by name.
  Future<int> commit(
    List<ImportedRow> rows, {
    required TransactionRepository transactions,
    required CategoryRepository categories,
    required Map<int, Account> accountsById,
  }) async {
    final now = DateTime.now();
    final catCache = <String, int>{};
    final txns = <Txn>[];
    for (final r in rows) {
      int? catId;
      if (r.categoryName != null) {
        final key = '${r.type.name}:${r.categoryName!.toLowerCase()}';
        catId = catCache[key] ??= await categories.findOrCreate(
          r.categoryName!,
          r.type == TxnType.income ? CategoryType.income : CategoryType.expense,
        );
      }
      txns.add(Txn(
        id: 0,
        type: r.type,
        amount: r.amount,
        currency: accountsById[r.accountId]!.currency,
        accountId: r.accountId,
        categoryId: catId,
        date: r.date,
        note: r.note,
        createdAt: now,
        updatedAt: now,
      ));
    }
    // One batch = one DB transaction: a failure leaves nothing half-imported,
    // so retrying can't create duplicates. (Categories created above are
    // reused by findOrCreate on retry.)
    await transactions.addAll(txns);
    return txns.length;
  }
}
