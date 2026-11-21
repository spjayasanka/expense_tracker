// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pennyfold';

  @override
  String get appTagline => 'Free · Offline · Private';

  @override
  String get offlineBadge =>
      'Works fully offline. Your data never leaves this device.';

  @override
  String get overview => 'Overview';

  @override
  String get transactions => 'Transactions';

  @override
  String get accounts => 'Accounts';

  @override
  String get categories => 'Categories';

  @override
  String get reports => 'Reports';

  @override
  String get budgets => 'Budgets';

  @override
  String get recurring => 'Recurring';

  @override
  String get exchangeRates => 'Exchange rates';

  @override
  String get backupAndData => 'Backup & data';

  @override
  String get settings => 'Settings';

  @override
  String get expense => 'Expense';

  @override
  String get income => 'Income';

  @override
  String get transfer => 'Transfer';

  @override
  String get transfers => 'Transfers';

  @override
  String get expenses => 'Expenses';

  @override
  String get balance => 'Balance';

  @override
  String get count => 'Count';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get accountBalance => 'Account balance';

  @override
  String get allAccounts => 'All accounts';

  @override
  String get amount => 'Amount';

  @override
  String get account => 'Account';

  @override
  String get category => 'Category';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get type => 'Type';

  @override
  String get name => 'Name';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Color';

  @override
  String get currency => 'Currency';

  @override
  String get period => 'Period';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirm';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get apply => 'Apply';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear all';

  @override
  String get undo => 'Undo';

  @override
  String get review => 'Review';

  @override
  String get restore => 'Restore';

  @override
  String get merge => 'Merge';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get never => 'Never';

  @override
  String get off => 'Off';

  @override
  String get required => 'Required';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get moreOptions => 'More options';

  @override
  String get reorder => 'Drag to reorder';

  @override
  String get iUnderstand => 'I understand';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get allTime => 'All time';

  @override
  String get thisMonth => 'This month';

  @override
  String get thisYear => 'This year';

  @override
  String get customRange => 'Custom range';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get periodAll => 'All';

  @override
  String get periodCustom => 'Custom';

  @override
  String get previousPeriod => 'Previous period';

  @override
  String get nextPeriod => 'Next period';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String everyNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String everyNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String everyNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String everyNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String get accountTypeLabel => 'Account type';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeCard => 'Card';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchHint => 'Search note, amount or category';

  @override
  String get searchCurrency => 'Search currency';

  @override
  String get addExpense => 'Add expense';

  @override
  String get addIncome => 'Add income';

  @override
  String addExpenseIn(String category, String amount) {
    return 'Add expense in $category. Spent $amount this period';
  }

  @override
  String get moreCategories => 'More categories';

  @override
  String get expensesByCategory => 'Expenses by category';

  @override
  String get expensesChartLabel =>
      'Expenses by category chart. Tap a segment to see its transactions.';

  @override
  String periodSummaryLabel(String income, String expenses, String balance) {
    return 'Income $income, expenses $expenses, balance $balance. Tap to see transactions.';
  }

  @override
  String recurringPendingBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recurring transactions need your confirmation',
      one: '1 recurring transaction needs your confirmation',
    );
    return '$_temp0';
  }

  @override
  String recurringCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count recurring transactions',
      one: 'Added 1 recurring transaction',
    );
    return '$_temp0';
  }

  @override
  String get confirmRecurringTitle => 'Confirm recurring transactions';

  @override
  String get newExpense => 'New expense';

  @override
  String get newIncome => 'New income';

  @override
  String get newTransfer => 'New transfer';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get chooseAccount => 'Choose account';

  @override
  String get chooseCategory => 'Choose category';

  @override
  String get fromAccount => 'From account';

  @override
  String get toAccount => 'To account';

  @override
  String get enterAmount => 'Enter an amount greater than zero';

  @override
  String get createAccountFirst => 'Create an account first';

  @override
  String get enterReceivedAmount => 'Enter the amount received';

  @override
  String receivedAmount(String currency) {
    return 'Amount received ($currency)';
  }

  @override
  String get receivedAmountHelp =>
      'Leave empty to convert with your saved exchange rate';

  @override
  String get repeat => 'Repeat';

  @override
  String get doesNotRepeat => 'Does not repeat';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get keyDivide => 'Divide';

  @override
  String get keyMultiply => 'Multiply';

  @override
  String get keyMinus => 'Minus';

  @override
  String get keyPlus => 'Plus';

  @override
  String get keyDecimal => 'Decimal point';

  @override
  String get keyBackspace => 'Backspace';

  @override
  String get keyEquals => 'Equals';

  @override
  String get filters => 'Filters';

  @override
  String get groupBy => 'Group by';

  @override
  String get groupByDate => 'Group by date';

  @override
  String get groupByCategory => 'Group by category';

  @override
  String get dateRange => 'Date range';

  @override
  String get anyDate => 'Any date';

  @override
  String get clearDateRange => 'Clear date range';

  @override
  String get noTransactions => 'No transactions';

  @override
  String get noTransactionsMessage =>
      'Tap a category on the home screen to add your first expense.';

  @override
  String get noMatches => 'Nothing matches your search or filters.';

  @override
  String nTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get newAccount => 'New account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get noAccounts => 'No accounts yet';

  @override
  String get noAccountsMessage =>
      'Add a money account such as Cash or Bank to start tracking.';

  @override
  String get accountName => 'Account name';

  @override
  String get defaultAccountName => 'Cash';

  @override
  String get initialBalance => 'Initial balance';

  @override
  String get initialBalanceHelp =>
      'What the account held before you started tracking';

  @override
  String get currentBalance => 'Current balance';

  @override
  String get currencyLocked => 'Can\'t change: the account has transactions';

  @override
  String get includeInTotal => 'Include in total balance';

  @override
  String get includeInTotalHelp =>
      'Turn off for savings or loans you don\'t want in your total';

  @override
  String get excludedFromTotal => 'Not in total';

  @override
  String get archived => 'Archived';

  @override
  String get archivedHelp => 'Hide from pickers; history is kept';

  @override
  String get chooseIcon => 'Choose icon';

  @override
  String deleteAccountTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deleteAccountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Its $count transactions will also be deleted. Consider archiving instead.',
      one:
          'Its 1 transaction will also be deleted. Consider archiving instead.',
      zero: 'This account has no transactions.',
    );
    return '$_temp0';
  }

  @override
  String missingRatesWarning(String codes) {
    return 'No exchange rate for $codes. Totals use 1:1 until you add one.';
  }

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get noCategories => 'No categories';

  @override
  String get hidden => 'Hidden';

  @override
  String get hiddenHelp =>
      'Hidden categories stay in reports but not on the home screen';

  @override
  String get mergeInto => 'Merge into…';

  @override
  String mergeCategoryTitle(String name) {
    return 'Merge \"$name\"';
  }

  @override
  String mergeCategoryMessage(int count, String from, String into) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transactions will move from $from to $into, and $from will be deleted.',
      one:
          '1 transaction will move from $from to $into, and $from will be deleted.',
    );
    return '$_temp0';
  }

  @override
  String get categoriesMerged => 'Categories merged';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteCategoryEmpty => 'This category has no transactions.';

  @override
  String deleteCategoryWithTxns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It has $count transactions. Move them to another category, or delete them too?',
      one: 'It has 1 transaction. Move it to another category, or delete it too?',
    );
    return '$_temp0';
  }

  @override
  String get moveTransactions => 'Move';

  @override
  String get deleteAll => 'Delete all';

  @override
  String get colorSwatch => 'Color swatch';

  @override
  String get customColor => 'Custom color';

  @override
  String get hue => 'Hue';

  @override
  String get lightness => 'Lightness';

  @override
  String get useThisColor => 'Use this color';

  @override
  String get byCategory => 'By category';

  @override
  String get avgDailySpending => 'Avg. daily spending';

  @override
  String get noDataForPeriod => 'No data for this period';

  @override
  String get categoryChartLabel =>
      'Category pie chart. Tap a segment to see its transactions.';

  @override
  String get topSpending => 'Top spending';

  @override
  String get topIncome => 'Top income';

  @override
  String get incomeVsExpenses => 'Income vs. expenses by month';

  @override
  String get monthlyChartLabel =>
      'Monthly income and expenses bar chart. Tap a month to see its transactions.';

  @override
  String get balanceOverTime => 'Balance over time';

  @override
  String balanceChartLabel(String start, String end) {
    return 'Balance line chart from $start to $end';
  }

  @override
  String get budget => 'Budget';

  @override
  String get newBudget => 'New budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get overallBudget => 'Overall budget';

  @override
  String get categoryBudget => 'Category';

  @override
  String get budgetLimit => 'Limit per period';

  @override
  String get budgetExists =>
      'A budget for this category and period already exists';

  @override
  String get noBudgets => 'No budgets yet';

  @override
  String get noBudgetsMessage =>
      'Set a monthly limit overall or per category and watch your progress.';

  @override
  String get budgetAlerts => 'Budget alerts';

  @override
  String get budgetAlertsHelp => 'Notify me at 80% and 100% of a budget';

  @override
  String get carryOver => 'Carry over';

  @override
  String get carryOverHelp =>
      'Roll what\'s left (or overspent) into the next period';

  @override
  String carriedOver(String amount) {
    return 'Carried over: $amount';
  }

  @override
  String spentOf(String spent, String limit) {
    return '$spent of $limit';
  }

  @override
  String remainingAmount(String amount) {
    return '$amount left';
  }

  @override
  String overBy(String amount) {
    return 'Over by $amount';
  }

  @override
  String get deleteBudget => 'Delete budget?';

  @override
  String get deleteBudgetMessage => 'Your transactions are not affected.';

  @override
  String budgetWarningTitle(String name) {
    return '$name: 80% of budget used';
  }

  @override
  String budgetExceededTitle(String name) {
    return '$name: budget reached';
  }

  @override
  String budgetAlertBody(String spent, String limit) {
    return 'Spent $spent of $limit';
  }

  @override
  String get newRecurring => 'New recurring';

  @override
  String get editRecurring => 'Edit recurring';

  @override
  String get noRecurring => 'No recurring transactions';

  @override
  String get noRecurringMessage =>
      'Add rent, salary or subscriptions once and Pennyfold records them for you.';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get finished => 'Finished';

  @override
  String get paused => 'Paused';

  @override
  String nextOn(String dates) {
    return 'Next: $dates';
  }

  @override
  String get asksFirst => 'Asks first';

  @override
  String remindsDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Reminder $days days before',
      one: 'Reminder 1 day before',
      zero: 'Reminder on the day',
    );
    return '$_temp0';
  }

  @override
  String get longPressToPause =>
      'Tip: long-press an item to pause or resume it.';

  @override
  String get billReminders => 'Bill reminders';

  @override
  String get billRemindersHelp =>
      'Notify me before recurring transactions are due';

  @override
  String get schedule => 'Schedule';

  @override
  String get every => 'Every';

  @override
  String get frequencyLabel => 'Frequency';

  @override
  String get startDate => 'Start date';

  @override
  String get nextDate => 'Next date';

  @override
  String get endDate => 'End date';

  @override
  String get autoCreate => 'Create automatically';

  @override
  String get autoCreateOnHelp =>
      'Added on the due date, even if the app was closed';

  @override
  String get autoCreateOffHelp => 'You\'ll be asked to confirm each one';

  @override
  String get reminder => 'Reminder';

  @override
  String get noReminder => 'No reminder';

  @override
  String get onTheDay => 'On the day';

  @override
  String daysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get deleteRecurring => 'Delete recurring transaction?';

  @override
  String get deleteRecurringMessage =>
      'Transactions it already created are kept.';

  @override
  String reminderTitle(String name) {
    return 'Upcoming: $name';
  }

  @override
  String reminderBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$amount is due in $days days',
      one: '$amount is due tomorrow',
      zero: '$amount is due today',
    );
    return '$_temp0';
  }

  @override
  String get notificationPermissionDenied =>
      'Notifications are blocked. Allow them in system settings to get alerts.';

  @override
  String get mainCurrency => 'Main currency';

  @override
  String get addRate => 'Add rate';

  @override
  String get ratesOfflineNote =>
      'Rates are entered by you and stored on this device. Pennyfold never downloads rates.';

  @override
  String get noRatesNeeded => 'All your accounts use the main currency';

  @override
  String get rateMissing => 'No rate set – tap to add';

  @override
  String rateUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String exchangeRateFor(String code) {
    return 'Exchange rate for $code';
  }

  @override
  String get ratesCleared =>
      'Main currency changed. Please re-enter your exchange rates.';

  @override
  String get backup => 'Backup';

  @override
  String get backupIntro =>
      'Backups are single files you keep wherever you like – your phone, an SD card or a USB drive. Nothing is uploaded.';

  @override
  String get createBackup => 'Create backup';

  @override
  String get createBackupHelp => 'Save a single file with all your data';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get restoreBackupHelp => 'Replace current data with a backup file';

  @override
  String get restoreBackupTitle => 'Restore this backup?';

  @override
  String restoreBackupMessage(int accounts, int transactions) {
    String _temp0 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts accounts',
      one: '1 account',
    );
    String _temp1 = intl.Intl.pluralLogic(
      transactions,
      locale: localeName,
      other: '$transactions transactions',
      one: '1 transaction',
    );
    return 'It contains $_temp0 and $_temp1. All current data will be replaced. A safety copy of your current data is kept in automatic backups.';
  }

  @override
  String get restoreDone => 'Backup restored';

  @override
  String get notABackup => 'That file is not a Pennyfold backup';

  @override
  String get backupCorrupted => 'That backup file is damaged';

  @override
  String get backupNewerVersion =>
      'That backup was made by a newer version of Pennyfold';

  @override
  String get autoBackup => 'Automatic backup';

  @override
  String get keepBackups => 'Keep last';

  @override
  String get backupNow => 'Back up now';

  @override
  String get neverBackedUp => 'No automatic backup yet';

  @override
  String lastBackup(String date, String time) {
    return 'Last: $date $time';
  }

  @override
  String get saveCopy => 'Save a copy…';

  @override
  String get saveCancelled => 'Not saved';

  @override
  String savedFile(String name) {
    return 'Saved $name';
  }

  @override
  String operationFailed(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get exportImport => 'Export & import';

  @override
  String get exportCsv => 'Export to CSV';

  @override
  String get exportXlsx => 'Export to Excel (.xlsx)';

  @override
  String get exportRange => 'Export which transactions?';

  @override
  String get nothingToExport => 'No transactions in that range';

  @override
  String get importCsv => 'Import from CSV';

  @override
  String get importCsvHelp => 'Map columns, preview, then import';

  @override
  String get importEmpty => 'That file is empty';

  @override
  String get importPreview => 'Preview';

  @override
  String get firstRowIsHeader => 'First row contains column names';

  @override
  String get columnMapping => 'Columns';

  @override
  String columnN(int n) {
    return 'Column $n';
  }

  @override
  String get notMapped => '— not used —';

  @override
  String get amountMeaning => 'Amounts are';

  @override
  String get signedAmounts => 'Negative = expense, positive = income';

  @override
  String get allExpenses => 'All expenses';

  @override
  String get allIncome => 'All income';

  @override
  String get defaultImportAccount =>
      'Account for rows without a matching account';

  @override
  String importSummary(int ok, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      ok,
      locale: localeName,
      other: '$ok rows ready',
      one: '1 row ready',
    );
    return '$_temp0, $skipped skipped';
  }

  @override
  String skippedLines(String lines) {
    return 'Skipped lines: $lines';
  }

  @override
  String importNRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count transactions',
      one: 'Import 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count transactions',
      one: 'Imported 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get deleteAllDataHelp => 'Erase accounts, transactions and settings';

  @override
  String get deleteAllDataTitle => 'Delete all data?';

  @override
  String get deleteAllDataMessage =>
      'This permanently erases everything stored in Pennyfold on this device. Make a backup first if you might need it.';

  @override
  String get deleteConfirmWord => 'DELETE';

  @override
  String typeToConfirm(String word) {
    return 'Type $word to confirm:';
  }

  @override
  String get deleteEverything => 'Delete everything';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get regional => 'Regional';

  @override
  String get firstDayOfWeek => 'First day of week';

  @override
  String get monthStartDay => 'Month starts on day';

  @override
  String get monthStartDayHelp => 'e.g. 25 if your salary arrives on the 25th';

  @override
  String get numberFormat => 'Number format';

  @override
  String get dateFormat => 'Date format';

  @override
  String get notifications => 'Notifications';

  @override
  String get security => 'Security';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockHelp => 'Require a PIN to open Pennyfold';

  @override
  String get changePin => 'Change PIN';

  @override
  String get pinChanged => 'PIN changed';

  @override
  String get biometricUnlock => 'Fingerprint / Face unlock';

  @override
  String get biometricUnlockHelp => 'Unlock with your device biometrics';

  @override
  String get biometricsUnavailable => 'Not available on this device';

  @override
  String get autoLock => 'Lock after';

  @override
  String get immediately => 'Immediately';

  @override
  String afterSeconds(int count) {
    return '$count seconds';
  }

  @override
  String afterMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get data => 'Data';

  @override
  String get about => 'About';

  @override
  String get aboutText =>
      'Free forever. No ads, no subscriptions, no accounts. Every feature is included.';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyText =>
      'Pennyfold has no internet permission and no analytics. Your data is stored only on this device.';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String tryAgainIn(int seconds) {
    return 'Too many attempts. Try again in $seconds s';
  }

  @override
  String get useBiometrics => 'Use fingerprint or face';

  @override
  String get unlockReason => 'Unlock Pennyfold';

  @override
  String get forgotPin => 'Forgot PIN?';

  @override
  String get forgotPinMessage =>
      'There is no account and no recovery email, so a forgotten PIN cannot be reset. The only option is to clear the app\'s data in your phone\'s settings, which erases everything. Restore a backup afterwards if you have one.';

  @override
  String get setPin => 'Set PIN';

  @override
  String get chooseNewPin => 'Choose a PIN';

  @override
  String get confirmPin => 'Enter the PIN again';

  @override
  String get pinRules => '4 to 6 digits';

  @override
  String get pinTooShort => 'Use at least 4 digits';

  @override
  String get pinMismatch => 'PINs didn\'t match. Try again.';

  @override
  String get pinWarning =>
      'If you forget your PIN it cannot be recovered – there are no accounts. You would have to clear the app\'s data, which erases everything not in a backup.';

  @override
  String pinProgress(int filled, int total) {
    return '$filled of $total digits entered';
  }

  @override
  String get introQuickTitle => 'Add spending in seconds';

  @override
  String get introQuickBody =>
      'Tap a category, type the amount, save. Three taps and you\'re done.';

  @override
  String get introAccountsTitle => 'Cash, cards and banks';

  @override
  String get introAccountsBody =>
      'Track as many money accounts as you like, in any currency, and move money between them.';

  @override
  String get introBackupTitle => 'Private and offline';

  @override
  String get introBackupBody =>
      'No sign-up and no internet. Everything stays on your phone – make backup files whenever you want.';

  @override
  String get getStarted => 'Get started';

  @override
  String pageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get setupTitle => 'Set up Pennyfold';

  @override
  String get setupIntro =>
      'Pick your main currency and create your first money account. You can change both later.';

  @override
  String get firstAccount => 'First account';

  @override
  String get startUsing => 'Start using Pennyfold';
}
