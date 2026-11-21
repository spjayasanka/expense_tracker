import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/core/money/money_format.dart';
import 'package:pennyfold/core/utils/calculator.dart';
import 'package:pennyfold/core/utils/date_range.dart';

void main() {
  group('MoneyFormatter', () {
    const f = MoneyFormatter();
    test('formats cents with grouping and symbol', () {
      expect(f.format(123456, 'USD'), r'$1,234.56');
      expect(f.format(-5, 'USD'), r'−$0.05');
      expect(f.format(1000, 'JPY'), '¥1,000');
      expect(f.format(1234567, 'KWD'), '1,234.567 KD');
      expect(f.format(150, 'USD', signed: true), r'+$1.50');
    });
    test('respects number format styles', () {
      const de = MoneyFormatter(style: NumberFormatStyle.dotComma);
      expect(de.formatNumber(123456789, 2), '1.234.567,89');
      const plain = MoneyFormatter(style: NumberFormatStyle.plainDot);
      expect(plain.formatNumber(123456789, 2), '1234567.89');
    });
    test('editable representation trims zeros', () {
      expect(MoneyFormatter.toEditable(1250, 2), '12.5');
      expect(MoneyFormatter.toEditable(1200, 2), '12');
      expect(MoneyFormatter.toEditable(7, 0), '7');
    });
  });

  group('parseMinorUnits', () {
    test('parses common notations', () {
      expect(parseMinorUnits('12.34', 2), 1234);
      expect(parseMinorUnits('12,34', 2), 1234);
      expect(parseMinorUnits('1,234.56', 2), 123456);
      expect(parseMinorUnits('1.234,56', 2), 123456);
      expect(parseMinorUnits('1,234', 2), 123400);
      expect(parseMinorUnits('-3.5', 2), -350);
      expect(parseMinorUnits('(3.50)', 2), -350);
      expect(parseMinorUnits('0.005', 2), 1); // half-up
      expect(parseMinorUnits('abc', 2), isNull);
      expect(parseMinorUnits('', 2), isNull);
      expect(parseMinorUnits('15', 0), 15);
    });
  });

  group('Calculator', () {
    CalculatorState type(String keys, {int dec = 2}) {
      var s = const CalculatorState.empty();
      for (final ch in keys.split('')) {
        s = switch (ch) {
          '+' => s.inputOperator(CalcOp.add),
          '-' => s.inputOperator(CalcOp.subtract),
          '*' => s.inputOperator(CalcOp.multiply),
          '/' => s.inputOperator(CalcOp.divide),
          '.' => s.inputDecimal(maxDecimals: dec),
          '<' => s.backspace(),
          _ => s.inputDigit(ch, maxDecimals: dec),
        };
      }
      return s;
    }

    test('exact decimal arithmetic', () {
      expect(type('0.1+0.2').evaluate(2), 30);
      expect(type('10/3').evaluate(2), 333);
      expect(type('2+3*4').evaluate(2), 1400);
      expect(type('100-20*2').evaluate(2), 6000);
      expect(type('12.50').evaluate(2), 1250);
    });
    test('limits decimals to currency precision', () {
      expect(type('1.239').display, '1.23');
      expect(type('1.5', dec: 0).evaluate(0), 15);
    });
    test('division by zero is not computable', () {
      expect(type('5/0').evaluate(2), isNull);
    });
    test('operator replacement, trailing operator, backspace', () {
      expect(type('5+*2').display, '5 × 2');
      expect(type('5+').evaluate(2), 500);
      expect(type('123<').display, '12');
      expect(type('12+<').display, '12');
    });
    test('equals collapses expression', () {
      expect(type('2*3').equals(2).display, '6');
    });
  });

  group('Periods', () {
    const prefs = CalendarPrefs(firstDayOfWeek: DateTime.monday, monthStartDay: 1);
    test('week respects first day of week', () {
      final r = periodContaining(PeriodType.week, DateTime(2026, 11, 12), prefs); // Thu
      expect(r.start, DateTime(2026, 11, 9));
      expect(r.end, DateTime(2026, 11, 16));
      final sun = periodContaining(PeriodType.week, DateTime(2026, 11, 12),
          const CalendarPrefs(firstDayOfWeek: DateTime.sunday));
      expect(sun.start, DateTime(2026, 11, 8));
    });
    test('month start day for salary cycles', () {
      const p = CalendarPrefs(monthStartDay: 25);
      final r = periodContaining(PeriodType.month, DateTime(2026, 11, 10), p);
      expect(r.start, DateTime(2026, 10, 25));
      expect(r.end, DateTime(2026, 11, 25));
      final next = shiftPeriod(PeriodType.month, r, 1, p);
      expect(next.start, DateTime(2026, 11, 25));
      final jan = shiftPeriod(PeriodType.month, r, 3, p);
      expect(jan.start, DateTime(2027, 1, 25));
    });
    test('addMonths clamps to month end', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });
  });
}
