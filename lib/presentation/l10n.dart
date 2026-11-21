import 'package:flutter/widgets.dart';

import '../domain/entities/entities.dart';
import '../l10n/gen/app_localizations.dart';

export '../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension EnumL10n on AppLocalizations {
  String accountType(AccountType t) => switch (t) {
        AccountType.cash => accountTypeCash,
        AccountType.bank => accountTypeBank,
        AccountType.card => accountTypeCard,
        AccountType.savings => accountTypeSavings,
        AccountType.investment => accountTypeInvestment,
        AccountType.other => accountTypeOther,
      };

  String txnType(TxnType t) => switch (t) {
        TxnType.expense => expense,
        TxnType.income => income,
        TxnType.transfer => transfer,
      };

  String frequency(RecurrenceFrequency f, int interval) => switch (f) {
        RecurrenceFrequency.daily => everyNDays(interval),
        RecurrenceFrequency.weekly => everyNWeeks(interval),
        RecurrenceFrequency.monthly => everyNMonths(interval),
        RecurrenceFrequency.yearly => everyNYears(interval),
      };

  String frequencyName(RecurrenceFrequency f) => switch (f) {
        RecurrenceFrequency.daily => daily,
        RecurrenceFrequency.weekly => weekly,
        RecurrenceFrequency.monthly => monthly,
        RecurrenceFrequency.yearly => yearly,
      };

  String budgetPeriod(BudgetPeriod p) => switch (p) {
        BudgetPeriod.weekly => weekly,
        BudgetPeriod.monthly => monthly,
        BudgetPeriod.yearly => yearly,
      };
}
