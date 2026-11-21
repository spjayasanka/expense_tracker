/// Pure domain entities. They have no dependency on Flutter, drift or any
/// other framework so business rules can be unit-tested in isolation.
///
/// All money amounts are integer minor units (cents) of the entity's
/// currency. Floating point is never used for money.
library;

enum TxnType { expense, income, transfer }

enum CategoryType { expense, income }

enum AccountType { cash, bank, card, savings, investment, other }

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

enum BudgetPeriod { weekly, monthly, yearly }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    required this.icon,
    required this.color,
    this.includeInTotal = true,
    this.sortOrder = 0,
    this.isArchived = false,
  });

  final int id;
  final String name;
  final AccountType type;
  final String currency;
  final int initialBalance;
  final String icon;
  final int color;
  final bool includeInTotal;
  final int sortOrder;
  final bool isArchived;

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    String? currency,
    int? initialBalance,
    String? icon,
    int? color,
    bool? includeInTotal,
    int? sortOrder,
    bool? isArchived,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        includeInTotal: includeInTotal ?? this.includeInTotal,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final int id;
  final String name;
  final CategoryType type;
  final String icon;
  final int color;
  final int sortOrder;
  final bool isHidden;

  Category copyWith({
    String? name,
    CategoryType? type,
    String? icon,
    int? color,
    int? sortOrder,
    bool? isHidden,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        sortOrder: sortOrder ?? this.sortOrder,
        isHidden: isHidden ?? this.isHidden,
      );
}

/// A money movement: expense, income or transfer between two accounts.
class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.toAmount,
    this.categoryId,
    this.note = '',
    this.recurringId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final TxnType type;

  /// Always positive, in minor units of [currency] (the source account's).
  final int amount;
  final String currency;
  final int accountId;

  /// Destination account for transfers.
  final int? toAccountId;

  /// Amount credited to [toAccountId] in its own currency. Null means the
  /// same as [amount] (same-currency transfer).
  final int? toAmount;
  final int? categoryId;
  final DateTime date;
  final String note;
  final int? recurringId;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get creditedAmount => toAmount ?? amount;

  Txn copyWith({
    int? id,
    TxnType? type,
    int? amount,
    String? currency,
    int? accountId,
    int? Function()? toAccountId,
    int? Function()? toAmount,
    int? Function()? categoryId,
    DateTime? date,
    String? note,
    int? Function()? recurringId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Txn(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        accountId: accountId ?? this.accountId,
        toAccountId: toAccountId != null ? toAccountId() : this.toAccountId,
        toAmount: toAmount != null ? toAmount() : this.toAmount,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        date: date ?? this.date,
        note: note ?? this.note,
        recurringId: recurringId != null ? recurringId() : this.recurringId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Budget {
  const Budget({
    required this.id,
    this.categoryId,
    required this.amount,
    this.period = BudgetPeriod.monthly,
    this.carryOver = false,
    required this.startDate,
  });

  final int id;

  /// Null for the overall budget.
  final int? categoryId;

  /// Limit per period, in minor units of the main currency.
  final int amount;
  final BudgetPeriod period;
  final bool carryOver;

  /// First day the budget applies; carry-over is accumulated from here.
  final DateTime startDate;

  bool get isOverall => categoryId == null;

  Budget copyWith({
    int? Function()? categoryId,
    int? amount,
    BudgetPeriod? period,
    bool? carryOver,
    DateTime? startDate,
  }) =>
      Budget(
        id: id,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        amount: amount ?? this.amount,
        period: period ?? this.period,
        carryOver: carryOver ?? this.carryOver,
        startDate: startDate ?? this.startDate,
      );
}

/// Template used by a recurring rule to create transactions.
class TxnTemplate {
  const TxnTemplate({
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.toAmount,
    this.categoryId,
    this.note = '',
  });

  final TxnType type;
  final int amount;
  final int accountId;
  final int? toAccountId;
  final int? toAmount;
  final int? categoryId;
  final String note;
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.template,
    required this.frequency,
    this.interval = 1,
    required this.startDate,
    required this.nextDate,
    this.endDate,
    this.autoCreate = true,
    this.isPaused = false,
    this.remindDaysBefore,
  });

  final int id;
  final TxnTemplate template;
  final RecurrenceFrequency frequency;

  /// Every [interval] units of [frequency] (e.g. every 2 weeks).
  final int interval;

  /// Anchor of the schedule (day-of-month for monthly rules comes from here).
  final DateTime startDate;

  /// Next occurrence that has not been generated or skipped yet.
  final DateTime nextDate;
  final DateTime? endDate;

  /// Create automatically when due, or ask the user to confirm first.
  final bool autoCreate;
  final bool isPaused;

  /// Days before [nextDate] to show a reminder; null disables reminders.
  final int? remindDaysBefore;

  RecurringRule copyWith({
    TxnTemplate? template,
    RecurrenceFrequency? frequency,
    int? interval,
    DateTime? startDate,
    DateTime? nextDate,
    DateTime? Function()? endDate,
    bool? autoCreate,
    bool? isPaused,
    int? Function()? remindDaysBefore,
  }) =>
      RecurringRule(
        id: id,
        template: template ?? this.template,
        frequency: frequency ?? this.frequency,
        interval: interval ?? this.interval,
        startDate: startDate ?? this.startDate,
        nextDate: nextDate ?? this.nextDate,
        endDate: endDate != null ? endDate() : this.endDate,
        autoCreate: autoCreate ?? this.autoCreate,
        isPaused: isPaused ?? this.isPaused,
        remindDaysBefore: remindDaysBefore != null ? remindDaysBefore() : this.remindDaysBefore,
      );
}

class ExchangeRate {
  const ExchangeRate({
    required this.currencyCode,
    required this.rateToMain,
    required this.updatedAt,
  });

  final String currencyCode;

  /// How many units of the main currency one unit of [currencyCode] is worth.
  final double rateToMain;
  final DateTime updatedAt;
}
