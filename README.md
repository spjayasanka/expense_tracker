# Pennyfold

A free, fully offline personal finance and expense tracker for Android and iOS, built with Flutter.

- **100% free.** No Pro tier, no in-app purchases, no ads, no billing or ad SDKs. Every feature is on from first launch.
- **100% offline.** No server, no cloud database, no analytics, no crash reporting, no remote config. The Android release build declares **no** `INTERNET` or `ACCESS_NETWORK_STATE` permission (they are stripped with `tools:node="remove"`).
- **No accounts.** No sign-up and no login. Open the app and start using it.
- **All data stays on the phone** in a local SQLite database. Android cloud backup and device-transfer are disabled too (`allowBackup="false"` plus `data_extraction_rules.xml`).

## Features

| Area | What you get |
|---|---|
| Home | Donut chart of expenses by category, with category bubbles around it. Tap a bubble to quick-add. The center shows income, expenses and the period's balance. Big − / + buttons. Swipe between periods. Day / Week / Month / Year / All / Custom range |
| Quick add | Tap a category → type the amount → Save (3 taps). The built-in keypad supports + − × ÷ and uses exact decimal arithmetic |
| Transactions | Expense, income and transfers (including cross-currency transfers). Back-dating, notes, edit, delete with undo. List grouped by date or by category with collapsible groups. Search by note, amount or category. Filter by account, category, type and date range |
| Categories | 12 expense and 4 income defaults. Create, rename, recolor, hide, reorder (drag) and delete. Merge two categories (moves transactions, budgets and recurring rules). 146 bundled icons and a palette plus custom color picker |
| Accounts | Unlimited accounts, each with its own currency, initial balance, icon and color. Per-account and combined balances. Option to exclude an account from the total. Archiving |
| Multi-currency | Full ISO 4217 list bundled. Exchange rates are entered manually and stored locally. Changing the main currency rebases the stored rates |
| Budgets | Overall and per-category budgets (weekly, monthly or yearly), with progress bars, carry-over of the remainder (or overspend), and local notifications at 80% and 100% |
| Recurring | Daily / weekly / monthly / yearly with any interval and an optional end date. Each rule either auto-creates on the due date or asks you to confirm. Anything that came due while the app was closed is generated when you open it. Pause, edit, and a reminder notification before the due date |
| Reports | Category pie (expense or income), monthly income-vs-expense bars, balance-over-time line, top categories and average daily spending. Tap any slice, bar or row to see its transactions |
| Backup & data | Single-file backup saved through the system save dialog. Restore through the system file picker, with validation and confirmation (a safety copy of current data is kept first). Optional daily or weekly automatic backups that keep the last N. CSV and Excel (.xlsx) export by date range. CSV import with column mapping and preview. Delete all data |
| App lock | Off by default. 4–6 digit PIN, hashed with PBKDF2-HMAC-SHA256 and a random salt in `flutter_secure_storage`. Fingerprint / Face ID. Auto-lock timeout. Cooldown after 5 wrong attempts. Clear warning that a forgotten PIN cannot be recovered |
| Personalization | Light, dark or system theme. First day of week. Month start day (e.g. the 25th for salary cycles). Number format (1,234.56 / 1.234,56 / 1 234,56 / 1'234.56 / plain). Date format |
| Widget | Android home-screen widget showing the total balance, with − / + quick-add buttons |
| First launch | 3 skippable intro screens, then pick a currency and create the first account. No permissions are requested up front: notification permission is requested only when you turn on an alert or reminder |

## Tech stack

- Flutter (stable 3.47) / Dart 3.13
- **drift** (SQLite) for storage, **Riverpod 3** for state
- **fl_chart** for charts, **flutter_local_notifications** for local-only notifications
- **flutter_secure_storage** + **local_auth** for the optional lock
- **file_picker**, **csv**, **excel** for backup and export
- **home_widget** for the Android widget

Fonts and icons are the Material set that ships with Flutter. No asset is downloaded at runtime.

## Architecture

```
lib/
  core/            money formatting & parsing, exact calculator, periods, currency list, icon library
  domain/          framework-free business logic
    entities/      Account, Category, Txn, Budget, RecurringRule, ExchangeRate, AppSettings
    repositories/  repository interfaces + TxnFilter
    services/      BalanceCalculator, CurrencyConverter, BudgetCalculator, Recurrence
    usecases/      RecurringGenerator, BudgetService
  data/            implementations
    db/            drift tables, AppDatabase (migrations, seeding), connection
    repositories/  drift repositories (SQL aggregates for large data sets)
    services/      backup, export/import, notifications, app lock, home widget
  presentation/    Riverpod providers, theme, widgets, screens
  l10n/            app_en.arb (all user-visible strings)
```

Key decisions:

- **Money is integer minor units** everywhere (`int` cents; 0 decimals for JPY, 3 for KWD). The keypad evaluates with BigInt rationals, so `0.1 + 0.2` is exactly `0.30`. Conversion between currencies rounds once, at the end.
- **Large data sets.** Totals, balances and chart data are computed with SQL `GROUP BY` aggregates over indexed columns, never by loading every row. The transaction list is a flat lazy `ListView.builder` (headers and rows), so 10,000+ transactions scroll smoothly.
- **Recurring schedules** are computed from the anchor date, so "monthly on the 31st" gives Jan 31, Feb 28, Mar 31 instead of drifting to the 28th.
- **Migrations.** `AppDatabase.schemaVersion` plus the `onUpgrade` step list. Restoring an older backup runs the migrations automatically. A backup made by a *newer* schema is refused.

## Setup

Prerequisites:

- Flutter stable (3.47 or newer): <https://docs.flutter.dev/get-started/install>
- Android: Android SDK with JDK 17, plus SDK platform 37, which flutter_local_notifications 23 requires. Install it with `sdkmanager "platforms;android-37.0"`. Gradle downloads the NDK on the first build.
- iOS: a Mac with Xcode 16 or newer and CocoaPods

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift code (already committed; re-run after schema changes)
flutter gen-l10n                                             # localizations (also runs automatically on build)
```

## Run

```bash
flutter run                 # debug on a connected device or emulator
flutter run --release
```

## Build

```bash
# Android
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release    # for Play Store

# iOS (on macOS)
cd ios && pod install && cd ..
flutter build ipa --release
```

Release builds are currently signed with the debug key (see `android/app/build.gradle.kts`). Add your own signing config before you publish.

### Verify there is no network permission

```bash
$ANDROID_HOME/build-tools/<version>/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
```

The output must not list `android.permission.INTERNET` or `ACCESS_NETWORK_STATE`. Debug builds do include `INTERNET`, because the Flutter tool needs it for hot reload (`android/app/src/debug/AndroidManifest.xml`).

## Tests

```bash
flutter test
```

- `test/core` – money formatting and parsing, calculator, period maths (week start, salary month)
- `test/domain` – balance calculation, currency conversion, budgets with carry-over and alerts, recurring generation (missed occurrences, confirmation mode, pause, month-end clamping), SQL aggregates and search
- `test/data` – backup → wipe → restore round trip, rejection of foreign or newer backups, auto-backup pruning, CSV import/export, PBKDF2 reference vector
- `test/widget` – the 3-tap quick-add flow, the "−" button flow with the calculator and category picker, validation, and first-launch onboarding

### Airplane-mode checklist (manual)

Turn on airplane mode before you install, then check each of these:

1. First launch: intro, currency, account. Add an expense in 3 taps.
2. Add income, a transfer, a back-dated expense, and an expense in a second currency (after setting its rate).
3. Search, filter, group by category, swipe to delete and undo.
4. Reports: tap a slice, a bar and a top-category row.
5. Create a budget, turn on alerts, and exceed 80%.
6. Create a monthly recurring rule with a start date in the past, and confirm it back-fills.
7. Create a backup, delete all data, restore the backup.
8. Export CSV and XLSX, then import the CSV.
9. Turn on the PIN and biometrics, background the app, and confirm it locks.
10. Add the home-screen widget and tap − / +.

## Home-screen widget

- **Android:** included (`BalanceWidgetProvider.kt`, `res/layout/balance_widget.xml`). Long-press the home screen, open Widgets, and pick Pennyfold.
- **iOS:** a WidgetKit extension can only be added from Xcode. The Dart side already writes `balance` / `balance_label` to the app group `group.com.pennyfold.app` and handles `pennyfold://add?type=expense|income` links (the URL scheme is registered in `Info.plist`). To enable it:
  1. In Xcode: File → New → Target → Widget Extension, and name it `PennyfoldWidget`.
  2. Add the App Group `group.com.pennyfold.app` to both the Runner and the widget targets.
  3. In the widget, read the values with `UserDefaults(suiteName: "group.com.pennyfold.app")?.string(forKey: "balance")`, and use `Link(destination: URL(string: "pennyfold://add?type=expense")!)` for the buttons.

## Localization

Every user-visible string is in `lib/l10n/app_en.arb`. To add a language, copy it to `app_<locale>.arb`, translate it, and run `flutter gen-l10n`. The default category names are seeded in English and the user can rename them.

## Privacy

Pennyfold never makes a network request. No identifiers are collected, and the app has nothing to send them to. Backups are plain SQLite files that the user saves wherever they choose.
