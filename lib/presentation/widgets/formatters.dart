import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/date_range.dart';
import '../../domain/entities/app_settings.dart';
import '../l10n.dart';
import '../providers/providers.dart';

/// Formatting bound to the user's number/date preferences.
class Formatters {
  Formatters(this.settings, this.locale);

  final AppSettings settings;
  final String locale;

  String money(int minor, String currency, {bool signed = false, bool compact = false}) =>
      settings.money.format(minor, currency, signed: signed, compact: compact);

  String main(int minor, {bool signed = false, bool compact = false}) =>
      money(minor, settings.mainCurrency, signed: signed, compact: compact);

  String date(DateTime d) => DateFormat(settings.dateFormat, locale).format(d);
  String dayMonth(DateTime d) => DateFormat.MMMd(locale).format(d);
  String weekdayDate(DateTime d) => '${DateFormat.EEEE(locale).format(d)}, ${date(d)}';
  String monthYear(DateTime d) => DateFormat.yMMMM(locale).format(d);
  String shortMonth(DateTime d) => DateFormat.MMM(locale).format(d);
  String year(DateTime d) => DateFormat.y(locale).format(d);
  String time(DateTime d) => DateFormat.Hm(locale).format(d);

  String range(DateRange r) {
    final last = r.lastDay;
    if (r.start.year == last.year && r.start.month == last.month && r.start.day == last.day) {
      return date(r.start);
    }
    return '${date(r.start)} – ${date(last)}';
  }

  /// Human label for a period (e.g. "November 2026", "Week of 9 Nov").
  String period(PeriodType type, DateRange r, AppLocalizations l10n, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    switch (type) {
      case PeriodType.day:
        if (r.start == today) return l10n.today;
        if (r.start == addDays(today, -1)) return l10n.yesterday;
        return weekdayDate(r.start);
      case PeriodType.week:
        return '${dayMonth(r.start)} – ${dayMonth(r.lastDay)}';
      case PeriodType.month:
        if (r.start.day == 1) return monthYear(r.start);
        return '${dayMonth(r.start)} – ${dayMonth(r.lastDay)}';
      case PeriodType.year:
        return year(r.start);
      case PeriodType.all:
        return l10n.allTime;
      case PeriodType.custom:
        return range(r);
    }
  }
}

final formattersProvider = Provider.family<Formatters, String>(
    (ref, locale) => Formatters(ref.watch(settingsProvider), locale));

extension FormattersX on WidgetRef {
  Formatters fmt(BuildContext context) =>
      watch(formattersProvider(Localizations.localeOf(context).toLanguageTag()));
}
