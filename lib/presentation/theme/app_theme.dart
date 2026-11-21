import 'package:flutter/material.dart';

/// Pennyfold brand: a calm leaf green with warm accents.
const Color kBrandSeed = Color(0xFF2E7D4F);

/// Semantic money colours with WCAG AA contrast on their surfaces.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({required this.income, required this.expense, required this.transfer});

  final Color income;
  final Color expense;
  final Color transfer;

  static const light = MoneyColors(
    income: Color(0xFF1B6E3A),
    expense: Color(0xFFB3261E),
    transfer: Color(0xFF3A5BA0),
  );
  static const dark = MoneyColors(
    income: Color(0xFF7DDC9A),
    expense: Color(0xFFFFB4AB),
    transfer: Color(0xFFAFC6FF),
  );

  @override
  MoneyColors copyWith({Color? income, Color? expense, Color? transfer}) => MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

extension MoneyColorsX on BuildContext {
  MoneyColors get moneyColors => Theme.of(this).extension<MoneyColors>() ?? MoneyColors.light;
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kBrandSeed, brightness: brightness);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    extensions: [brightness == Brightness.light ? MoneyColors.light : MoneyColors.dark],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
