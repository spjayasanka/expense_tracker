import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pennyfold'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Free · Offline · Private'**
  String get appTagline;

  /// No description provided for @offlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Works fully offline. Your data never leaves this device.'**
  String get offlineBadge;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @exchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get exchangeRates;

  /// No description provided for @backupAndData.
  ///
  /// In en, this message translates to:
  /// **'Backup & data'**
  String get backupAndData;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get count;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get totalBalance;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account balance'**
  String get accountBalance;

  /// No description provided for @allAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get allAccounts;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get invalidNumber;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get reorder;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get iUnderstand;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get customRange;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @periodAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get periodAll;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// No description provided for @previousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get previousPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get nextPeriod;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String everyNDays(int count);

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String everyNWeeks(int count);

  /// No description provided for @everyNMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String everyNMonths(int count);

  /// No description provided for @everyNYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year} other{Every {count} years}}'**
  String everyNYears(int count);

  /// No description provided for @accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountTypeLabel;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get accountTypeCard;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @accountTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get accountTypeOther;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search note, amount or category'**
  String get searchHint;

  /// No description provided for @searchCurrency.
  ///
  /// In en, this message translates to:
  /// **'Search currency'**
  String get searchCurrency;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get addIncome;

  /// No description provided for @addExpenseIn.
  ///
  /// In en, this message translates to:
  /// **'Add expense in {category}. Spent {amount} this period'**
  String addExpenseIn(String category, String amount);

  /// No description provided for @moreCategories.
  ///
  /// In en, this message translates to:
  /// **'More categories'**
  String get moreCategories;

  /// No description provided for @expensesByCategory.
  ///
  /// In en, this message translates to:
  /// **'Expenses by category'**
  String get expensesByCategory;

  /// No description provided for @expensesChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses by category chart. Tap a segment to see its transactions.'**
  String get expensesChartLabel;

  /// No description provided for @periodSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Income {income}, expenses {expenses}, balance {balance}. Tap to see transactions.'**
  String periodSummaryLabel(String income, String expenses, String balance);

  /// No description provided for @recurringPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recurring transaction needs your confirmation} other{{count} recurring transactions need your confirmation}}'**
  String recurringPendingBanner(int count);

  /// No description provided for @recurringCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 recurring transaction} other{Added {count} recurring transactions}}'**
  String recurringCreated(int count);

  /// No description provided for @confirmRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm recurring transactions'**
  String get confirmRecurringTitle;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpense;

  /// No description provided for @newIncome.
  ///
  /// In en, this message translates to:
  /// **'New income'**
  String get newIncome;

  /// No description provided for @newTransfer.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get newTransfer;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @chooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get chooseAccount;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get chooseCategory;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero'**
  String get enterAmount;

  /// No description provided for @createAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Create an account first'**
  String get createAccountFirst;

  /// No description provided for @enterReceivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount received'**
  String get enterReceivedAmount;

  /// No description provided for @receivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount received ({currency})'**
  String receivedAmount(String currency);

  /// No description provided for @receivedAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to convert with your saved exchange rate'**
  String get receivedAmountHelp;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @doesNotRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get doesNotRepeat;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeleted;

  /// No description provided for @keyDivide.
  ///
  /// In en, this message translates to:
  /// **'Divide'**
  String get keyDivide;

  /// No description provided for @keyMultiply.
  ///
  /// In en, this message translates to:
  /// **'Multiply'**
  String get keyMultiply;

  /// No description provided for @keyMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get keyMinus;

  /// No description provided for @keyPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get keyPlus;

  /// No description provided for @keyDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal point'**
  String get keyDecimal;

  /// No description provided for @keyBackspace.
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get keyBackspace;

  /// No description provided for @keyEquals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get keyEquals;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @groupByDate.
  ///
  /// In en, this message translates to:
  /// **'Group by date'**
  String get groupByDate;

  /// No description provided for @groupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Group by category'**
  String get groupByCategory;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get anyDate;

  /// No description provided for @clearDateRange.
  ///
  /// In en, this message translates to:
  /// **'Clear date range'**
  String get clearDateRange;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @noTransactionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap a category on the home screen to add your first expense.'**
  String get noTransactionsMessage;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search or filters.'**
  String get noMatches;

  /// No description provided for @nTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String nTransactions(int count);

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get newAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// No description provided for @noAccountsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a money account such as Cash or Bank to start tracking.'**
  String get noAccountsMessage;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @defaultAccountName.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get defaultAccountName;

  /// No description provided for @initialBalance.
  ///
  /// In en, this message translates to:
  /// **'Initial balance'**
  String get initialBalance;

  /// No description provided for @initialBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'What the account held before you started tracking'**
  String get initialBalanceHelp;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get currentBalance;

  /// No description provided for @currencyLocked.
  ///
  /// In en, this message translates to:
  /// **'Can\'t change: the account has transactions'**
  String get currencyLocked;

  /// No description provided for @includeInTotal.
  ///
  /// In en, this message translates to:
  /// **'Include in total balance'**
  String get includeInTotal;

  /// No description provided for @includeInTotalHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off for savings or loans you don\'t want in your total'**
  String get includeInTotalHelp;

  /// No description provided for @excludedFromTotal.
  ///
  /// In en, this message translates to:
  /// **'Not in total'**
  String get excludedFromTotal;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @archivedHelp.
  ///
  /// In en, this message translates to:
  /// **'Hide from pickers; history is kept'**
  String get archivedHelp;

  /// No description provided for @chooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose icon'**
  String get chooseIcon;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteAccountTitle(String name);

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This account has no transactions.} =1{Its 1 transaction will also be deleted. Consider archiving instead.} other{Its {count} transactions will also be deleted. Consider archiving instead.}}'**
  String deleteAccountMessage(int count);

  /// No description provided for @missingRatesWarning.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate for {codes}. Totals use 1:1 until you add one.'**
  String missingRatesWarning(String codes);

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @hiddenHelp.
  ///
  /// In en, this message translates to:
  /// **'Hidden categories stay in reports but not on the home screen'**
  String get hiddenHelp;

  /// No description provided for @mergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into…'**
  String get mergeInto;

  /// No description provided for @mergeCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge \"{name}\"'**
  String mergeCategoryTitle(String name);

  /// No description provided for @mergeCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction will move from {from} to {into}, and {from} will be deleted.} other{{count} transactions will move from {from} to {into}, and {from} will be deleted.}}'**
  String mergeCategoryMessage(int count, String from, String into);

  /// No description provided for @categoriesMerged.
  ///
  /// In en, this message translates to:
  /// **'Categories merged'**
  String get categoriesMerged;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @deleteCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'This category has no transactions.'**
  String get deleteCategoryEmpty;

  /// No description provided for @deleteCategoryWithTxns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It has 1 transaction. Move it to another category, or delete it too?} other{It has {count} transactions. Move them to another category, or delete them too?}}'**
  String deleteCategoryWithTxns(int count);

  /// No description provided for @moveTransactions.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveTransactions;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @colorSwatch.
  ///
  /// In en, this message translates to:
  /// **'Color swatch'**
  String get colorSwatch;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @lightness.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get lightness;

  /// No description provided for @useThisColor.
  ///
  /// In en, this message translates to:
  /// **'Use this color'**
  String get useThisColor;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get byCategory;

  /// No description provided for @avgDailySpending.
  ///
  /// In en, this message translates to:
  /// **'Avg. daily spending'**
  String get avgDailySpending;

  /// No description provided for @noDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noDataForPeriod;

  /// No description provided for @categoryChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Category pie chart. Tap a segment to see its transactions.'**
  String get categoryChartLabel;

  /// No description provided for @topSpending.
  ///
  /// In en, this message translates to:
  /// **'Top spending'**
  String get topSpending;

  /// No description provided for @topIncome.
  ///
  /// In en, this message translates to:
  /// **'Top income'**
  String get topIncome;

  /// No description provided for @incomeVsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Income vs. expenses by month'**
  String get incomeVsExpenses;

  /// No description provided for @monthlyChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly income and expenses bar chart. Tap a month to see its transactions.'**
  String get monthlyChartLabel;

  /// No description provided for @balanceOverTime.
  ///
  /// In en, this message translates to:
  /// **'Balance over time'**
  String get balanceOverTime;

  /// No description provided for @balanceChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance line chart from {start} to {end}'**
  String balanceChartLabel(String start, String end);

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get newBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @overallBudget.
  ///
  /// In en, this message translates to:
  /// **'Overall budget'**
  String get overallBudget;

  /// No description provided for @categoryBudget.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryBudget;

  /// No description provided for @budgetLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit per period'**
  String get budgetLimit;

  /// No description provided for @budgetExists.
  ///
  /// In en, this message translates to:
  /// **'A budget for this category and period already exists'**
  String get budgetExists;

  /// No description provided for @noBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get noBudgets;

  /// No description provided for @noBudgetsMessage.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly limit overall or per category and watch your progress.'**
  String get noBudgetsMessage;

  /// No description provided for @budgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlerts;

  /// No description provided for @budgetAlertsHelp.
  ///
  /// In en, this message translates to:
  /// **'Notify me at 80% and 100% of a budget'**
  String get budgetAlertsHelp;

  /// No description provided for @carryOver.
  ///
  /// In en, this message translates to:
  /// **'Carry over'**
  String get carryOver;

  /// No description provided for @carryOverHelp.
  ///
  /// In en, this message translates to:
  /// **'Roll what\'s left (or overspent) into the next period'**
  String get carryOverHelp;

  /// No description provided for @carriedOver.
  ///
  /// In en, this message translates to:
  /// **'Carried over: {amount}'**
  String carriedOver(String amount);

  /// No description provided for @spentOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {limit}'**
  String spentOf(String spent, String limit);

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String remainingAmount(String amount);

  /// No description provided for @overBy.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overBy(String amount);

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete budget?'**
  String get deleteBudget;

  /// No description provided for @deleteBudgetMessage.
  ///
  /// In en, this message translates to:
  /// **'Your transactions are not affected.'**
  String get deleteBudgetMessage;

  /// No description provided for @budgetWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: 80% of budget used'**
  String budgetWarningTitle(String name);

  /// No description provided for @budgetExceededTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: budget reached'**
  String budgetExceededTitle(String name);

  /// No description provided for @budgetAlertBody.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent} of {limit}'**
  String budgetAlertBody(String spent, String limit);

  /// No description provided for @newRecurring.
  ///
  /// In en, this message translates to:
  /// **'New recurring'**
  String get newRecurring;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring'**
  String get editRecurring;

  /// No description provided for @noRecurring.
  ///
  /// In en, this message translates to:
  /// **'No recurring transactions'**
  String get noRecurring;

  /// No description provided for @noRecurringMessage.
  ///
  /// In en, this message translates to:
  /// **'Add rent, salary or subscriptions once and Pennyfold records them for you.'**
  String get noRecurringMessage;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @nextOn.
  ///
  /// In en, this message translates to:
  /// **'Next: {dates}'**
  String nextOn(String dates);

  /// No description provided for @asksFirst.
  ///
  /// In en, this message translates to:
  /// **'Asks first'**
  String get asksFirst;

  /// No description provided for @remindsDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Reminder on the day} =1{Reminder 1 day before} other{Reminder {days} days before}}'**
  String remindsDaysBefore(int days);

  /// No description provided for @longPressToPause.
  ///
  /// In en, this message translates to:
  /// **'Tip: long-press an item to pause or resume it.'**
  String get longPressToPause;

  /// No description provided for @billReminders.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get billReminders;

  /// No description provided for @billRemindersHelp.
  ///
  /// In en, this message translates to:
  /// **'Notify me before recurring transactions are due'**
  String get billRemindersHelp;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @nextDate.
  ///
  /// In en, this message translates to:
  /// **'Next date'**
  String get nextDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @autoCreate.
  ///
  /// In en, this message translates to:
  /// **'Create automatically'**
  String get autoCreate;

  /// No description provided for @autoCreateOnHelp.
  ///
  /// In en, this message translates to:
  /// **'Added on the due date, even if the app was closed'**
  String get autoCreateOnHelp;

  /// No description provided for @autoCreateOffHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be asked to confirm each one'**
  String get autoCreateOffHelp;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @noReminder.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get noReminder;

  /// No description provided for @onTheDay.
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get onTheDay;

  /// No description provided for @daysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before} other{{days} days before}}'**
  String daysBefore(int days);

  /// No description provided for @deleteRecurring.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring transaction?'**
  String get deleteRecurring;

  /// No description provided for @deleteRecurringMessage.
  ///
  /// In en, this message translates to:
  /// **'Transactions it already created are kept.'**
  String get deleteRecurringMessage;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming: {name}'**
  String reminderTitle(String name);

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{{amount} is due today} =1{{amount} is due tomorrow} other{{amount} is due in {days} days}}'**
  String reminderBody(String amount, int days);

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them in system settings to get alerts.'**
  String get notificationPermissionDenied;

  /// No description provided for @mainCurrency.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get mainCurrency;

  /// No description provided for @addRate.
  ///
  /// In en, this message translates to:
  /// **'Add rate'**
  String get addRate;

  /// No description provided for @ratesOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Rates are entered by you and stored on this device. Pennyfold never downloads rates.'**
  String get ratesOfflineNote;

  /// No description provided for @noRatesNeeded.
  ///
  /// In en, this message translates to:
  /// **'All your accounts use the main currency'**
  String get noRatesNeeded;

  /// No description provided for @rateMissing.
  ///
  /// In en, this message translates to:
  /// **'No rate set – tap to add'**
  String get rateMissing;

  /// No description provided for @rateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String rateUpdated(String date);

  /// No description provided for @exchangeRateFor.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate for {code}'**
  String exchangeRateFor(String code);

  /// No description provided for @ratesCleared.
  ///
  /// In en, this message translates to:
  /// **'Main currency changed. Please re-enter your exchange rates.'**
  String get ratesCleared;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Backups are single files you keep wherever you like – your phone, an SD card or a USB drive. Nothing is uploaded.'**
  String get backupIntro;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @createBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Save a single file with all your data'**
  String get createBackupHelp;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Replace current data with a backup file'**
  String get restoreBackupHelp;

  /// No description provided for @restoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get restoreBackupTitle;

  /// No description provided for @restoreBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'It contains {accounts, plural, =1{1 account} other{{accounts} accounts}} and {transactions, plural, =1{1 transaction} other{{transactions} transactions}}. All current data will be replaced. A safety copy of your current data is kept in automatic backups.'**
  String restoreBackupMessage(int accounts, int transactions);

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get restoreDone;

  /// No description provided for @notABackup.
  ///
  /// In en, this message translates to:
  /// **'That file is not a Pennyfold backup'**
  String get notABackup;

  /// No description provided for @backupCorrupted.
  ///
  /// In en, this message translates to:
  /// **'That backup file is damaged'**
  String get backupCorrupted;

  /// No description provided for @backupNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'That backup was made by a newer version of Pennyfold'**
  String get backupNewerVersion;

  /// No description provided for @autoBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get autoBackup;

  /// No description provided for @keepBackups.
  ///
  /// In en, this message translates to:
  /// **'Keep last'**
  String get keepBackups;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @neverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup yet'**
  String get neverBackedUp;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last: {date} {time}'**
  String lastBackup(String date, String time);

  /// No description provided for @saveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy…'**
  String get saveCopy;

  /// No description provided for @saveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get saveCancelled;

  /// No description provided for @savedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String savedFile(String name);

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String operationFailed(String error);

  /// No description provided for @exportImport.
  ///
  /// In en, this message translates to:
  /// **'Export & import'**
  String get exportImport;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get exportCsv;

  /// No description provided for @exportXlsx.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel (.xlsx)'**
  String get exportXlsx;

  /// No description provided for @exportRange.
  ///
  /// In en, this message translates to:
  /// **'Export which transactions?'**
  String get exportRange;

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No transactions in that range'**
  String get nothingToExport;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import from CSV'**
  String get importCsv;

  /// No description provided for @importCsvHelp.
  ///
  /// In en, this message translates to:
  /// **'Map columns, preview, then import'**
  String get importCsvHelp;

  /// No description provided for @importEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file is empty'**
  String get importEmpty;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get importPreview;

  /// No description provided for @firstRowIsHeader.
  ///
  /// In en, this message translates to:
  /// **'First row contains column names'**
  String get firstRowIsHeader;

  /// No description provided for @columnMapping.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columnMapping;

  /// No description provided for @columnN.
  ///
  /// In en, this message translates to:
  /// **'Column {n}'**
  String columnN(int n);

  /// No description provided for @notMapped.
  ///
  /// In en, this message translates to:
  /// **'— not used —'**
  String get notMapped;

  /// No description provided for @amountMeaning.
  ///
  /// In en, this message translates to:
  /// **'Amounts are'**
  String get amountMeaning;

  /// No description provided for @signedAmounts.
  ///
  /// In en, this message translates to:
  /// **'Negative = expense, positive = income'**
  String get signedAmounts;

  /// No description provided for @allExpenses.
  ///
  /// In en, this message translates to:
  /// **'All expenses'**
  String get allExpenses;

  /// No description provided for @allIncome.
  ///
  /// In en, this message translates to:
  /// **'All income'**
  String get allIncome;

  /// No description provided for @defaultImportAccount.
  ///
  /// In en, this message translates to:
  /// **'Account for rows without a matching account'**
  String get defaultImportAccount;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{ok, plural, =1{1 row ready} other{{ok} rows ready}}, {skipped} skipped'**
  String importSummary(int ok, int skipped);

  /// No description provided for @skippedLines.
  ///
  /// In en, this message translates to:
  /// **'Skipped lines: {lines}'**
  String skippedLines(String lines);

  /// No description provided for @importNRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 transaction} other{Import {count} transactions}}'**
  String importNRows(int count);

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 transaction} other{Imported {count} transactions}}'**
  String importDone(int count);

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataHelp.
  ///
  /// In en, this message translates to:
  /// **'Erase accounts, transactions and settings'**
  String get deleteAllDataHelp;

  /// No description provided for @deleteAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get deleteAllDataTitle;

  /// No description provided for @deleteAllDataMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases everything stored in Pennyfold on this device. Make a backup first if you might need it.'**
  String get deleteAllDataMessage;

  /// No description provided for @deleteConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteConfirmWord;

  /// No description provided for @typeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm:'**
  String typeToConfirm(String word);

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteEverything;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @regional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get regional;

  /// No description provided for @firstDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'First day of week'**
  String get firstDayOfWeek;

  /// No description provided for @monthStartDay.
  ///
  /// In en, this message translates to:
  /// **'Month starts on day'**
  String get monthStartDay;

  /// No description provided for @monthStartDayHelp.
  ///
  /// In en, this message translates to:
  /// **'e.g. 25 if your salary arrives on the 25th'**
  String get monthStartDayHelp;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get numberFormat;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get dateFormat;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockHelp.
  ///
  /// In en, this message translates to:
  /// **'Require a PIN to open Pennyfold'**
  String get appLockHelp;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get pinChanged;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint / Face unlock'**
  String get biometricUnlock;

  /// No description provided for @biometricUnlockHelp.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your device biometrics'**
  String get biometricUnlockHelp;

  /// No description provided for @biometricsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get biometricsUnavailable;

  /// No description provided for @autoLock.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get autoLock;

  /// No description provided for @immediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get immediately;

  /// No description provided for @afterSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String afterSeconds(int count);

  /// No description provided for @afterMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String afterMinutes(int count);

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'Free forever. No ads, no subscriptions, no accounts. Every feature is included.'**
  String get aboutText;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Pennyfold has no internet permission and no analytics. Your data is stored only on this device.'**
  String get privacyText;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @tryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s'**
  String tryAgainIn(int seconds);

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get useBiometrics;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pennyfold'**
  String get unlockReason;

  /// No description provided for @forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPin;

  /// No description provided for @forgotPinMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no account and no recovery email, so a forgotten PIN cannot be reset. The only option is to clear the app\'s data in your phone\'s settings, which erases everything. Restore a backup afterwards if you have one.'**
  String get forgotPinMessage;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setPin;

  /// No description provided for @chooseNewPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get chooseNewPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get confirmPin;

  /// No description provided for @pinRules.
  ///
  /// In en, this message translates to:
  /// **'4 to 6 digits'**
  String get pinRules;

  /// No description provided for @pinTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 digits'**
  String get pinTooShort;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs didn\'t match. Try again.'**
  String get pinMismatch;

  /// No description provided for @pinWarning.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN it cannot be recovered – there are no accounts. You would have to clear the app\'s data, which erases everything not in a backup.'**
  String get pinWarning;

  /// No description provided for @pinProgress.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {total} digits entered'**
  String pinProgress(int filled, int total);

  /// No description provided for @introQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Add spending in seconds'**
  String get introQuickTitle;

  /// No description provided for @introQuickBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a category, type the amount, save. Three taps and you\'re done.'**
  String get introQuickBody;

  /// No description provided for @introAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash, cards and banks'**
  String get introAccountsTitle;

  /// No description provided for @introAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'Track as many money accounts as you like, in any currency, and move money between them.'**
  String get introAccountsBody;

  /// No description provided for @introBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Private and offline'**
  String get introBackupTitle;

  /// No description provided for @introBackupBody.
  ///
  /// In en, this message translates to:
  /// **'No sign-up and no internet. Everything stays on your phone – make backup files whenever you want.'**
  String get introBackupBody;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @pageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageIndicator(int current, int total);

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up Pennyfold'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick your main currency and create your first money account. You can change both later.'**
  String get setupIntro;

  /// No description provided for @firstAccount.
  ///
  /// In en, this message translates to:
  /// **'First account'**
  String get firstAccount;

  /// No description provided for @startUsing.
  ///
  /// In en, this message translates to:
  /// **'Start using Pennyfold'**
  String get startUsing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
