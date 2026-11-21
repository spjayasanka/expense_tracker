import '../entities/entities.dart';
import 'currency_converter.dart';

/// Aggregated money flows of one account, in the account's own currency.
class AccountFlows {
  const AccountFlows({
    this.income = 0,
    this.expense = 0,
    this.transferOut = 0,
    this.transferIn = 0,
  });

  final int income;
  final int expense;
  final int transferOut;
  final int transferIn;

  static const zero = AccountFlows();

  AccountFlows operator +(AccountFlows o) => AccountFlows(
        income: income + o.income,
        expense: expense + o.expense,
        transferOut: transferOut + o.transferOut,
        transferIn: transferIn + o.transferIn,
      );
}

class AccountBalance {
  const AccountBalance(this.account, this.balance);
  final Account account;

  /// In the account's own currency.
  final int balance;
}

/// Pure balance rules shared by the UI, widgets and tests.
class BalanceCalculator {
  const BalanceCalculator();

  /// Balance = initial + income − expense − transfers out + transfers in.
  int accountBalance(Account account, AccountFlows flows) =>
      account.initialBalance +
      flows.income -
      flows.expense -
      flows.transferOut +
      flows.transferIn;

  /// Computes flows for each account directly from a list of transactions.
  /// Used for small sets and tests; the database computes the same thing
  /// with SQL aggregates for large data sets.
  Map<int, AccountFlows> flowsFromTransactions(Iterable<Txn> txns) {
    final map = <int, AccountFlows>{};
    void add(int id, AccountFlows f) => map[id] = (map[id] ?? AccountFlows.zero) + f;
    for (final t in txns) {
      switch (t.type) {
        case TxnType.expense:
          add(t.accountId, AccountFlows(expense: t.amount));
        case TxnType.income:
          add(t.accountId, AccountFlows(income: t.amount));
        case TxnType.transfer:
          add(t.accountId, AccountFlows(transferOut: t.amount));
          if (t.toAccountId != null) {
            add(t.toAccountId!, AccountFlows(transferIn: t.creditedAmount));
          }
      }
    }
    return map;
  }

  List<AccountBalance> balances(List<Account> accounts, Map<int, AccountFlows> flows) => [
        for (final a in accounts)
          AccountBalance(a, accountBalance(a, flows[a.id] ?? AccountFlows.zero)),
      ];

  /// Total in the main currency over accounts that are included in the
  /// total and not archived.
  int totalBalance(List<AccountBalance> balances, CurrencyConverter converter) {
    var total = 0;
    for (final b in balances) {
      if (!b.account.includeInTotal || b.account.isArchived) continue;
      total += converter.toMain(b.balance, b.account.currency);
    }
    return total;
  }
}
