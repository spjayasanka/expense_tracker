import '../../core/money/money_format.dart';
import '../../core/utils/date_range.dart';

enum AppThemeMode { system, light, dark }

enum AutoBackupFrequency { off, daily, weekly }

/// Supported date display patterns (intl `DateFormat` skeletons).
const List<String> kDateFormats = [
  'd MMM y',
  'MMM d, y',
  'dd/MM/y',
  'MM/dd/y',
  'y-MM-dd',
  'dd.MM.y',
];

/// User preferences. Persisted in the local database (so they are part of
/// backups), except app-lock secrets which live in secure storage.
class AppSettings {
  const AppSettings({
    this.mainCurrency = 'USD',
    this.themeMode = AppThemeMode.system,
    this.firstDayOfWeek = DateTime.monday,
    this.monthStartDay = 1,
    this.numberFormat = NumberFormatStyle.commaDot,
    this.dateFormat = 'd MMM y',
    this.onboardingDone = false,
    this.budgetAlertsEnabled = false,
    this.recurringRemindersEnabled = false,
    this.autoBackup = AutoBackupFrequency.off,
    this.autoBackupKeep = 5,
    this.lastAutoBackup,
    this.defaultAccountId,
  });

  final String mainCurrency;
  final AppThemeMode themeMode;
  final int firstDayOfWeek;
  final int monthStartDay;
  final NumberFormatStyle numberFormat;
  final String dateFormat;
  final bool onboardingDone;
  final bool budgetAlertsEnabled;
  final bool recurringRemindersEnabled;
  final AutoBackupFrequency autoBackup;
  final int autoBackupKeep;
  final DateTime? lastAutoBackup;
  final int? defaultAccountId;

  CalendarPrefs get calendar =>
      CalendarPrefs(firstDayOfWeek: firstDayOfWeek, monthStartDay: monthStartDay);

  MoneyFormatter get money => MoneyFormatter(style: numberFormat);

  AppSettings copyWith({
    String? mainCurrency,
    AppThemeMode? themeMode,
    int? firstDayOfWeek,
    int? monthStartDay,
    NumberFormatStyle? numberFormat,
    String? dateFormat,
    bool? onboardingDone,
    bool? budgetAlertsEnabled,
    bool? recurringRemindersEnabled,
    AutoBackupFrequency? autoBackup,
    int? autoBackupKeep,
    DateTime? Function()? lastAutoBackup,
    int? Function()? defaultAccountId,
  }) =>
      AppSettings(
        mainCurrency: mainCurrency ?? this.mainCurrency,
        themeMode: themeMode ?? this.themeMode,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
        monthStartDay: monthStartDay ?? this.monthStartDay,
        numberFormat: numberFormat ?? this.numberFormat,
        dateFormat: dateFormat ?? this.dateFormat,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
        recurringRemindersEnabled: recurringRemindersEnabled ?? this.recurringRemindersEnabled,
        autoBackup: autoBackup ?? this.autoBackup,
        autoBackupKeep: autoBackupKeep ?? this.autoBackupKeep,
        lastAutoBackup: lastAutoBackup != null ? lastAutoBackup() : this.lastAutoBackup,
        defaultAccountId: defaultAccountId != null ? defaultAccountId() : this.defaultAccountId,
      );

  /// Serialises to string key/value pairs for the settings table.
  Map<String, String> toMap() => {
        'mainCurrency': mainCurrency,
        'themeMode': themeMode.name,
        'firstDayOfWeek': '$firstDayOfWeek',
        'monthStartDay': '$monthStartDay',
        'numberFormat': numberFormat.name,
        'dateFormat': dateFormat,
        'onboardingDone': '$onboardingDone',
        'budgetAlertsEnabled': '$budgetAlertsEnabled',
        'recurringRemindersEnabled': '$recurringRemindersEnabled',
        'autoBackup': autoBackup.name,
        'autoBackupKeep': '$autoBackupKeep',
        'lastAutoBackup': lastAutoBackup?.toIso8601String() ?? '',
        'defaultAccountId': defaultAccountId?.toString() ?? '',
      };

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AppSettings(
      mainCurrency: m['mainCurrency'] ?? d.mainCurrency,
      themeMode: pick(AppThemeMode.values, m['themeMode'], d.themeMode),
      firstDayOfWeek: int.tryParse(m['firstDayOfWeek'] ?? '')?.clamp(1, 7) ?? d.firstDayOfWeek,
      monthStartDay: int.tryParse(m['monthStartDay'] ?? '')?.clamp(1, 28) ?? d.monthStartDay,
      numberFormat: pick(NumberFormatStyle.values, m['numberFormat'], d.numberFormat),
      dateFormat: kDateFormats.contains(m['dateFormat']) ? m['dateFormat']! : d.dateFormat,
      onboardingDone: m['onboardingDone'] == 'true',
      budgetAlertsEnabled: m['budgetAlertsEnabled'] == 'true',
      recurringRemindersEnabled: m['recurringRemindersEnabled'] == 'true',
      autoBackup: pick(AutoBackupFrequency.values, m['autoBackup'], d.autoBackup),
      autoBackupKeep: int.tryParse(m['autoBackupKeep'] ?? '')?.clamp(1, 50) ?? d.autoBackupKeep,
      lastAutoBackup: DateTime.tryParse(m['lastAutoBackup'] ?? ''),
      defaultAccountId: int.tryParse(m['defaultAccountId'] ?? ''),
    );
  }
}
