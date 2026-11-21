import 'package:drift/drift.dart';

import '../../domain/entities/entities.dart';
import '../db/app_database.dart';

extension AccountRowX on AccountRow {
  Account toDomain() => Account(
        id: id,
        name: name,
        type: type,
        currency: currency,
        initialBalance: initialBalance,
        icon: icon,
        color: color,
        includeInTotal: includeInTotal,
        sortOrder: sortOrder,
        isArchived: isArchived,
      );
}

extension AccountX on Account {
  AccountsCompanion toCompanion({bool withId = false}) => AccountsCompanion(
        id: withId ? Value(id) : const Value.absent(),
        name: Value(name),
        type: Value(type),
        currency: Value(currency.toUpperCase()),
        initialBalance: Value(initialBalance),
        icon: Value(icon),
        color: Value(color),
        includeInTotal: Value(includeInTotal),
        sortOrder: Value(sortOrder),
        isArchived: Value(isArchived),
      );
}

extension CategoryRowX on CategoryRow {
  Category toDomain() => Category(
        id: id,
        name: name,
        type: type,
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        isHidden: isHidden,
      );
}

extension CategoryX on Category {
  CategoriesCompanion toCompanion({bool withId = false}) => CategoriesCompanion(
        id: withId ? Value(id) : const Value.absent(),
        name: Value(name),
        type: Value(type),
        icon: Value(icon),
        color: Value(color),
        sortOrder: Value(sortOrder),
        isHidden: Value(isHidden),
      );
}

extension TxnRowX on TxnRow {
  Txn toDomain() => Txn(
        id: id,
        type: type,
        amount: amount,
        currency: currency,
        accountId: accountId,
        toAccountId: toAccountId,
        toAmount: toAmount,
        categoryId: categoryId,
        date: date,
        note: note,
        recurringId: recurringId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension TxnX on Txn {
  TransactionsCompanion toCompanion({bool withId = false}) {
    final isTransfer = type == TxnType.transfer;
    return TransactionsCompanion(
      id: withId ? Value(id) : const Value.absent(),
      type: Value(type),
      amount: Value(amount.abs()),
      currency: Value(currency.toUpperCase()),
      accountId: Value(accountId),
      toAccountId: Value(isTransfer ? toAccountId : null),
      toAmount: Value(isTransfer ? toAmount : null),
      categoryId: Value(isTransfer ? null : categoryId),
      date: Value(date),
      note: Value(note),
      recurringId: Value(recurringId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}

extension BudgetRowX on BudgetRow {
  Budget toDomain() => Budget(
        id: id,
        categoryId: categoryId,
        amount: amount,
        period: period,
        carryOver: carryOver,
        startDate: startDate,
      );
}

extension BudgetX on Budget {
  BudgetsCompanion toCompanion({bool withId = false}) => BudgetsCompanion(
        id: withId ? Value(id) : const Value.absent(),
        categoryId: Value(categoryId),
        amount: Value(amount),
        period: Value(period),
        carryOver: Value(carryOver),
        startDate: Value(startDate),
      );
}

extension RecurringRowX on RecurringRow {
  RecurringRule toDomain() => RecurringRule(
        id: id,
        template: TxnTemplate(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: toAccountId,
          toAmount: toAmount,
          categoryId: categoryId,
          note: note,
        ),
        frequency: frequency,
        interval: interval,
        startDate: startDate,
        nextDate: nextDate,
        endDate: endDate,
        autoCreate: autoCreate,
        isPaused: isPaused,
        remindDaysBefore: remindDaysBefore,
      );
}

extension RecurringX on RecurringRule {
  RecurringRulesCompanion toCompanion({bool withId = false}) {
    final isTransfer = template.type == TxnType.transfer;
    return RecurringRulesCompanion(
      id: withId ? Value(id) : const Value.absent(),
      type: Value(template.type),
      amount: Value(template.amount.abs()),
      accountId: Value(template.accountId),
      toAccountId: Value(isTransfer ? template.toAccountId : null),
      toAmount: Value(isTransfer ? template.toAmount : null),
      categoryId: Value(isTransfer ? null : template.categoryId),
      note: Value(template.note),
      frequency: Value(frequency),
      interval: Value(interval < 1 ? 1 : interval),
      startDate: Value(startDate),
      nextDate: Value(nextDate),
      endDate: Value(endDate),
      autoCreate: Value(autoCreate),
      isPaused: Value(isPaused),
      remindDaysBefore: Value(remindDaysBefore),
    );
  }
}

extension ExchangeRateRowX on ExchangeRateRow {
  ExchangeRate toDomain() =>
      ExchangeRate(currencyCode: currencyCode, rateToMain: rateToMain, updatedAt: updatedAt);
}
