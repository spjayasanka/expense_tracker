import '../../core/money/currencies.dart';
import '../entities/entities.dart';

/// Converts minor-unit amounts into the main currency using exchange rates
/// that the user entered manually. Nothing is ever fetched online.
class CurrencyConverter {
  CurrencyConverter({required this.mainCurrency, Map<String, double> rates = const {}})
      : _rates = {for (final e in rates.entries) e.key.toUpperCase(): e.value};

  factory CurrencyConverter.fromRates(String mainCurrency, Iterable<ExchangeRate> rates) =>
      CurrencyConverter(
        mainCurrency: mainCurrency,
        rates: {for (final r in rates) r.currencyCode: r.rateToMain},
      );

  final String mainCurrency;
  final Map<String, double> _rates;

  /// Rate of [code] to the main currency, or null if the user has not set one.
  double? rateFor(String code) {
    if (code.toUpperCase() == mainCurrency.toUpperCase()) return 1.0;
    return _rates[code.toUpperCase()];
  }

  bool hasRate(String code) => rateFor(code) != null;

  /// Converts [minor] units of [currency] to minor units of the main
  /// currency. Handles differing minor-unit digits (e.g. JPY → USD).
  ///
  /// When no rate is stored, a 1:1 rate is assumed (the UI warns about
  /// missing rates via [missingRates]).
  int toMain(int minor, String currency) => convert(minor, currency, mainCurrency);

  /// Converts between two arbitrary currencies via the main currency.
  int convert(int minor, String from, String to) {
    if (from.toUpperCase() == to.toUpperCase()) return minor;
    final fromRate = rateFor(from) ?? 1.0;
    final toRate = rateFor(to) ?? 1.0;
    final fromDec = currencyFor(from).decimals;
    final toDec = currencyFor(to).decimals;
    final major = minor / _pow10(fromDec);
    final converted = major * fromRate / toRate;
    return (converted * _pow10(toDec)).round();
  }

  /// Sums per-currency amounts into the main currency.
  int sumToMain(Map<String, int> amountsByCurrency) {
    var total = 0;
    amountsByCurrency.forEach((code, minor) => total += toMain(minor, code));
    return total;
  }

  /// Currencies among [codes] that have no stored rate.
  Set<String> missingRates(Iterable<String> codes) =>
      codes.where((c) => !hasRate(c)).map((c) => c.toUpperCase()).toSet();
}

num _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
