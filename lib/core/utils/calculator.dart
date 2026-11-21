import '../money/money_format.dart';

/// Operators supported by the built-in amount keypad.
enum CalcOp {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CalcOp(this.symbol);
  final String symbol;
}

/// A tiny, exact calculator for the amount keypad.
///
/// Numbers are kept as decimal strings while typing and evaluated with
/// rational arithmetic (BigInt numerator/denominator) so that
/// `0.1 + 0.2` is exactly `0.3` and money never touches floating point.
class CalculatorState {
  const CalculatorState._(this.tokens);

  const CalculatorState.empty() : tokens = const [];

  /// Alternating number strings and operator symbols, e.g. `['12.5', '+', '3']`.
  final List<String> tokens;

  factory CalculatorState.fromMinor(int minor, int decimals) {
    if (minor == 0) return const CalculatorState.empty();
    return CalculatorState._([MoneyFormatter.toEditable(minor.abs(), decimals)]);
  }

  bool get isEmpty => tokens.isEmpty;

  bool get hasOperator => tokens.any(_isOp);

  String get display => tokens.isEmpty ? '0' : tokens.join(' ');

  static bool _isOp(String t) => CalcOp.values.any((o) => o.symbol == t);

  CalculatorState inputDigit(String digit, {required int maxDecimals}) {
    assert(RegExp(r'^\d$').hasMatch(digit));
    final list = [...tokens];
    if (list.isEmpty || _isOp(list.last)) {
      list.add(digit);
    } else {
      final cur = list.last;
      final dot = cur.indexOf('.');
      if (dot != -1 && cur.length - dot - 1 >= maxDecimals) return this;
      if (cur.replaceAll('.', '').length >= 12) return this;
      list[list.length - 1] = cur == '0' ? digit : cur + digit;
    }
    return CalculatorState._(list);
  }

  CalculatorState inputDecimal({required int maxDecimals}) {
    if (maxDecimals == 0) return this;
    final list = [...tokens];
    if (list.isEmpty || _isOp(list.last)) {
      list.add('0.');
    } else if (!list.last.contains('.')) {
      list[list.length - 1] = '${list.last}.';
    } else {
      return this;
    }
    return CalculatorState._(list);
  }

  CalculatorState inputOperator(CalcOp op) {
    final list = [...tokens];
    if (list.isEmpty) return this;
    if (_isOp(list.last)) {
      list[list.length - 1] = op.symbol;
    } else {
      list.add(op.symbol);
    }
    return CalculatorState._(list);
  }

  CalculatorState backspace() {
    if (tokens.isEmpty) return this;
    final list = [...tokens];
    final last = list.last;
    if (_isOp(last) || last.length <= 1) {
      list.removeLast();
    } else {
      list[list.length - 1] = last.substring(0, last.length - 1);
    }
    return CalculatorState._(list);
  }

  CalculatorState clear() => const CalculatorState.empty();

  /// Evaluates the expression into minor units (rounded half-up), or null
  /// when it is not computable (e.g. division by zero).
  int? evaluate(int decimals) {
    final list = [...tokens];
    while (list.isNotEmpty && _isOp(list.last)) {
      list.removeLast();
    }
    if (list.isEmpty) return 0;
    final values = <_Rational>[];
    final ops = <String>[];
    for (final t in list) {
      if (_isOp(t)) {
        ops.add(t);
      } else {
        final r = _Rational.parse(t);
        if (r == null) return null;
        values.add(r);
      }
    }
    // First pass: × and ÷.
    final v2 = <_Rational>[values.first];
    final o2 = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final rhs = values[i + 1];
      if (op == CalcOp.multiply.symbol) {
        v2[v2.length - 1] = v2.last * rhs;
      } else if (op == CalcOp.divide.symbol) {
        if (rhs.isZero) return null;
        v2[v2.length - 1] = v2.last / rhs;
      } else {
        o2.add(op);
        v2.add(rhs);
      }
    }
    var acc = v2.first;
    for (var i = 0; i < o2.length; i++) {
      acc = o2[i] == CalcOp.add.symbol ? acc + v2[i + 1] : acc - v2[i + 1];
    }
    return acc.toMinor(decimals);
  }

  /// Collapses the expression into its result (the "=" key).
  CalculatorState equals(int decimals) {
    final v = evaluate(decimals);
    if (v == null) return this;
    return CalculatorState.fromMinor(v, decimals);
  }
}

class _Rational {
  _Rational(BigInt n, BigInt d)
      : num = d.isNegative ? -n : n,
        den = d.abs();

  final BigInt num;
  final BigInt den;

  static _Rational? parse(String s) {
    if (s.isEmpty || s == '.') return null;
    final parts = s.split('.');
    final whole = parts[0].isEmpty ? '0' : parts[0];
    final frac = parts.length > 1 ? parts[1] : '';
    final den = BigInt.from(10).pow(frac.length);
    final n = BigInt.parse(whole) * den + (frac.isEmpty ? BigInt.zero : BigInt.parse(frac));
    return _Rational(n, den);
  }

  bool get isZero => num == BigInt.zero;

  _Rational operator +(_Rational o) => _Rational(num * o.den + o.num * den, den * o.den);
  _Rational operator -(_Rational o) => _Rational(num * o.den - o.num * den, den * o.den);
  _Rational operator *(_Rational o) => _Rational(num * o.num, den * o.den);
  _Rational operator /(_Rational o) => _Rational(num * o.den, den * o.num);

  /// Largest amount accepted, in minor units. Keeps SQLite SUM() far from
  /// 64-bit overflow even across many rows.
  static final _maxMinor = BigInt.from(10).pow(15);

  /// Null when the result is too large to store safely.
  int? toMinor(int decimals) {
    final scaled = num * BigInt.from(10).pow(decimals);
    final q = scaled ~/ den;
    final r = scaled.remainder(den).abs();
    var result = q;
    if (r * BigInt.two >= den) {
      result += scaled.isNegative ? -BigInt.one : BigInt.one;
    }
    if (result.abs() > _maxMinor) return null;
    return result.toInt();
  }
}
