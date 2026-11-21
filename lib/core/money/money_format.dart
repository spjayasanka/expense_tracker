import 'currencies.dart';

/// How grouping and decimal separators are rendered.
enum NumberFormatStyle {
  /// 1,234.56
  commaDot(',', '.'),

  /// 1.234,56
  dotComma('.', ','),

  /// 1 234,56
  spaceComma(' ', ','),

  /// 1'234.56
  apostropheDot('\'', '.'),

  /// 1234.56 (no grouping)
  plainDot('', '.');

  const NumberFormatStyle(this.group, this.decimal);
  final String group;
  final String decimal;
}

/// Formats integer minor units (e.g. cents) for display.
///
/// Money is never held as floating point: all arithmetic happens on [int]s
/// and only the final string rendering inserts a decimal separator.
class MoneyFormatter {
  const MoneyFormatter({this.style = NumberFormatStyle.commaDot});

  final NumberFormatStyle style;

  /// Formats [minor] in [currencyCode], e.g. `$1,234.50`.
  String format(
    int minor,
    String currencyCode, {
    bool showSymbol = true,
    bool signed = false,
    bool compact = false,
  }) {
    final currency = currencyFor(currencyCode);
    final negative = minor < 0;
    final number = compact
        ? _compact(minor.abs(), currency.decimals)
        : formatNumber(minor.abs(), currency.decimals);
    final sign = negative ? '−' : (signed && minor > 0 ? '+' : '');
    if (!showSymbol) return '$sign$number';
    final symbol = currency.symbol;
    // Symbols made of letters read better after the number.
    final suffix = RegExp(r'^[A-Za-z]').hasMatch(symbol) && symbol.length > 1;
    return suffix ? '$sign$number $symbol' : '$sign$symbol$number';
  }

  /// Formats [minor] with [decimals] fraction digits, no symbol, no sign.
  String formatNumber(int minor, int decimals) {
    final abs = minor.abs();
    final factor = _pow10(decimals);
    final whole = abs ~/ factor;
    final frac = abs % factor;
    final wholeStr = _group(whole.toString());
    final sign = minor < 0 ? '-' : '';
    if (decimals == 0) return '$sign$wholeStr';
    return '$sign$wholeStr${style.decimal}${frac.toString().padLeft(decimals, '0')}';
  }

  /// Plain editable representation (no grouping, '.' decimal), e.g. `1234.5`.
  static String toEditable(int minor, int decimals) {
    final factor = _pow10(decimals);
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final whole = abs ~/ factor;
    final frac = abs % factor;
    if (decimals == 0 || frac == 0) return '$sign$whole';
    var f = frac.toString().padLeft(decimals, '0');
    while (f.endsWith('0')) {
      f = f.substring(0, f.length - 1);
    }
    return '$sign$whole.$f';
  }

  String _compact(int minor, int decimals) {
    final value = minor / _pow10(decimals);
    if (value >= 1e9) return '${_trim(value / 1e9)}B';
    if (value >= 1e6) return '${_trim(value / 1e6)}M';
    if (value >= 1e4) return '${_trim(value / 1e3)}K';
    return formatNumber(minor, decimals);
  }

  String _trim(double v) {
    final s = v.toStringAsFixed(1);
    final t = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return t.replaceAll('.', style.decimal);
  }

  String _group(String digits) {
    if (style.group.isEmpty || digits.length <= 3) return digits;
    final buf = StringBuffer();
    final first = digits.length % 3;
    if (first > 0) buf.write(digits.substring(0, first));
    for (var i = first; i < digits.length; i += 3) {
      if (buf.isNotEmpty) buf.write(style.group);
      buf.write(digits.substring(i, i + 3));
    }
    return buf.toString();
  }
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

int pow10(int n) => _pow10(n);

/// Parses a user-typed decimal string ("12.5", "12,50", "1 234.56") into
/// minor units. Returns null when the text is not a number.
int? parseMinorUnits(String input, int decimals, {String? decimalSeparator}) {
  var s = input.trim().replaceAll(RegExp(r'[\s  \x27]'), '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('-') || s.startsWith('−')) {
    negative = true;
    s = s.substring(1);
  } else if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (decimalSeparator != null) {
    // Known format (e.g. detected for a whole import file): the other
    // separator is grouping, so no guessing is needed.
    final group = decimalSeparator == '.' ? ',' : '.';
    s = s.replaceAll(group, '');
    if (decimalSeparator.allMatches(s).length > 1) return null;
    if (decimalSeparator == ',') s = s.replaceAll(',', '.');
  }
  // Decide which separator is the decimal one: the last of '.' or ','.
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String intPart;
  String fracPart;
  if (lastDot == -1 && lastComma == -1) {
    intPart = s;
    fracPart = '';
  } else {
    final decIdx = lastDot > lastComma ? lastDot : lastComma;
    final sepChar = s[decIdx];
    final otherChar = sepChar == '.' ? ',' : '.';
    final occurrences = sepChar.allMatches(s).length;
    final tail = s.substring(decIdx + 1);
    // "1,234" or "1.234.567": a single separator followed by exactly three
    // digits with the other separator absent is ambiguous; treat repeated
    // separators as grouping.
    final looksLikeThousands = sepChar == ',' &&
        occurrences == 1 &&
        !s.contains(otherChar) &&
        tail.length == 3 &&
        decimals != 3;
    if ((occurrences > 1 && !s.contains(otherChar)) || looksLikeThousands) {
      intPart = s.replaceAll(sepChar, '');
      fracPart = '';
    } else {
      intPart = s.substring(0, decIdx).replaceAll(otherChar, '').replaceAll(sepChar, '');
      fracPart = tail;
    }
  }
  if (intPart.isEmpty) intPart = '0';
  if (!RegExp(r'^\d+$').hasMatch(intPart) ||
      (fracPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fracPart))) {
    return null;
  }
  // Round half-up on the digits beyond the currency precision.
  final frac = fracPart.padRight(decimals + 1, '0');
  final keep = frac.substring(0, decimals);
  final roundDigit = int.parse(frac[decimals]);
  var value = BigInt.parse(intPart) * BigInt.from(_pow10(decimals)) +
      (keep.isEmpty ? BigInt.zero : BigInt.parse(keep));
  if (roundDigit >= 5) value += BigInt.one;
  if (!value.isValidInt) return null;
  final result = value.toInt();
  return negative ? -result : result;
}

/// Guesses the decimal separator used by a column of amounts (e.g. an import
/// file) so values like "1.500" aren't misread. Returns null when the column
/// gives no clear signal, leaving [parseMinorUnits] to decide per value.
String? detectDecimalSeparator(Iterable<String> values) {
  var dot = 0;
  var comma = 0;
  final dotDecimal = RegExp(r'\.\d{1,2}$');
  final commaDecimal = RegExp(r',\d{1,2}$');
  for (final raw in values) {
    final v = raw.trim().replaceAll(RegExp(r'[()]'), '');
    if (v.isEmpty) continue;
    final lastDot = v.lastIndexOf('.');
    final lastComma = v.lastIndexOf(',');
    if (lastDot != -1 && lastComma != -1) {
      // Both present: the last one is the decimal separator.
      lastDot > lastComma ? dot++ : comma++;
    } else if (dotDecimal.hasMatch(v)) {
      dot++;
    } else if (commaDecimal.hasMatch(v)) {
      comma++;
    } else if (RegExp(r'\.\d{3}\.').hasMatch(v)) {
      comma++; // 1.234.567 → dots are grouping
    } else if (RegExp(r',\d{3},').hasMatch(v)) {
      dot++;
    }
  }
  if (dot > comma) return '.';
  if (comma > dot) return ',';
  return null;
}
