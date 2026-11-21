/// A half-open date-time interval `[start, end)` in local time.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;

  /// Exclusive upper bound.
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Number of calendar days covered (at least 1).
  int get dayCount {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final days = DateTime.utc(e.year, e.month, e.day)
        .difference(DateTime.utc(s.year, s.month, s.day))
        .inDays;
    return days < 1 ? 1 : days;
  }

  /// The last day included in the range (for display).
  DateTime get lastDay => end.subtract(const Duration(days: 1));

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start – $end)';
}

enum PeriodType { day, week, month, year, all, custom }

/// Calendar settings that affect how periods are computed.
class CalendarPrefs {
  const CalendarPrefs({this.firstDayOfWeek = DateTime.monday, this.monthStartDay = 1});

  /// [DateTime.monday] (1) … [DateTime.sunday] (7).
  final int firstDayOfWeek;

  /// Day of the month on which a "month" begins, 1–28 (e.g. 25 for salary
  /// cycles).
  final int monthStartDay;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Adds [months] to [d], clamping the day to the end of the target month.
DateTime addMonths(DateTime d, int months, {int? anchorDay}) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final day = anchorDay ?? d.day;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, day > last ? last : day, d.hour, d.minute, d.second);
}

/// Adds calendar days (DST safe, because it re-creates the local date).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute, d.second);

/// Earliest bound used for "all time".
final DateTime kAllTimeStart = DateTime(1970);
final DateTime kAllTimeEnd = DateTime(9999);

/// The period of [type] containing [anchor].
DateRange periodContaining(PeriodType type, DateTime anchor, CalendarPrefs prefs) {
  final d = dateOnly(anchor);
  switch (type) {
    case PeriodType.day:
      return DateRange(d, addDays(d, 1));
    case PeriodType.week:
      final diff = (d.weekday - prefs.firstDayOfWeek) % 7;
      final s = addDays(d, -diff);
      return DateRange(s, addDays(s, 7));
    case PeriodType.month:
      final startDay = prefs.monthStartDay.clamp(1, 28);
      final s = d.day >= startDay
          ? DateTime(d.year, d.month, startDay)
          : DateTime(d.year, d.month - 1, startDay);
      return DateRange(s, DateTime(s.year, s.month + 1, startDay));
    case PeriodType.year:
      return DateRange(DateTime(d.year), DateTime(d.year + 1));
    case PeriodType.all:
    case PeriodType.custom:
      return DateRange(kAllTimeStart, kAllTimeEnd);
  }
}

/// Shifts a period of [type] by [offset] steps (negative = past).
DateRange shiftPeriod(PeriodType type, DateRange range, int offset, CalendarPrefs prefs) {
  if (offset == 0) return range;
  switch (type) {
    case PeriodType.day:
      return periodContaining(type, addDays(range.start, offset), prefs);
    case PeriodType.week:
      return periodContaining(type, addDays(range.start, 7 * offset), prefs);
    case PeriodType.month:
      final startDay = prefs.monthStartDay.clamp(1, 28);
      final s = DateTime(range.start.year, range.start.month + offset, startDay);
      return DateRange(s, DateTime(s.year, s.month + 1, startDay));
    case PeriodType.year:
      return DateRange(
        DateTime(range.start.year + offset),
        DateTime(range.start.year + offset + 1),
      );
    case PeriodType.all:
      return range;
    case PeriodType.custom:
      final days = range.dayCount;
      return DateRange(addDays(range.start, days * offset), addDays(range.end, days * offset));
  }
}

/// Month buckets `[start, end)` covering [range] using the month start day.
List<DateRange> monthBuckets(DateRange range, CalendarPrefs prefs) {
  final result = <DateRange>[];
  var cur = periodContaining(PeriodType.month, range.start, prefs);
  while (cur.start.isBefore(range.end)) {
    result.add(cur);
    cur = shiftPeriod(PeriodType.month, cur, 1, prefs);
    if (result.length > 1200) break;
  }
  return result;
}
