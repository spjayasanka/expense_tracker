import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennyfold/app.dart';
import 'package:pennyfold/data/db/app_database.dart';
import 'package:pennyfold/data/repositories/drift_repositories.dart';
import 'package:pennyfold/data/services/app_lock_service.dart';
import 'package:pennyfold/data/services/home_widget_service.dart';
import 'package:pennyfold/domain/entities/app_settings.dart';
import 'package:pennyfold/domain/entities/entities.dart';
import 'package:pennyfold/domain/repositories/repositories.dart';
import 'package:pennyfold/presentation/providers/providers.dart';

import '../helpers/test_db.dart';

class _NoLock extends AppLockService {
  @override
  Future<LockConfig> load() async => const LockConfig();
}

class _NoWidget extends HomeWidgetService {
  const _NoWidget();
  @override
  Future<void> init() async {}
  @override
  Future<void> update({required String balanceLabel, required String balance}) async {}
  @override
  Future<Uri?> initialLaunchUri() async => null;
  @override
  Stream<Uri?> get clicks => const Stream.empty();
}

/// Hands the test database to the app without closing it on dispose; the
/// test closes it itself in real async time.
class _TestDbController extends DatabaseController {
  _TestDbController(this.db);
  final AppDatabase db;
  @override
  AppDatabase build() => db;
}

Future<(AppDatabase, Repos)> _setup({bool onboarded = true}) async {
  final db = newTestDb();
  final repos = Repos(db);
  if (onboarded) {
    final cash = await repos.account('Cash', initial: 10000);
    await repos.settings.save(const AppSettings().copyWith(
      onboardingDone: true,
      mainCurrency: 'USD',
      defaultAccountId: () => cash,
    ));
  }
  return (db, repos);
}

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [
        databaseProvider.overrideWith(() => _TestDbController(db)),
        appLockServiceProvider.overrideWithValue(_NoLock()),
        homeWidgetServiceProvider.overrideWithValue(const _NoWidget()),
      ],
      child: const PennyfoldApp(),
    );

/// Pumps frames until [finder] matches (drift streams resolve over a few
/// microtask/timer turns), failing after [max] frames.
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int max = 50}) async {
  for (var i = 0; i < max; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  // Real async: drift's close waits on timers that fake time won't fire.
  await tester.runAsync(db.close);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('quick add: tap category â†’ type amount â†’ save (3 taps)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (db, repos) = await _setup();
    final food = (await repos.categories.getAll()).firstWhere((c) => c.name == 'Food');

    await tester.pumpWidget(_app(db));
    final bubble = find.byKey(Key('category-bubble-${food.id}'));
    await pumpUntil(tester, bubble);

    // Tap 1: the category bubble opens the editor with Food preselected.
    await tester.tap(bubble);
    await pumpUntil(tester, find.byKey(const Key('save-button')));
    await tester.pump(const Duration(seconds: 1)); // let the page transition finish
    expect(find.text('Food'), findsWidgets);

    // Tap 2: type the amount on the built-in keypad.
    await tester.tap(find.byKey(const Key('key-1')));
    await tester.tap(find.byKey(const Key('key-2')));
    await tester.pump();
    expect(find.textContaining('12'), findsWidgets);

    // Tap 3: save.
    await tester.tap(find.byKey(const Key('save-button')));
    await pumpUntil(tester, bubble);

    final txns = (await tester.runAsync(() => repos.transactions.query(const TxnFilter())))!;
    expect(txns, hasLength(1));
    expect(txns.single.amount, 1200);
    expect(txns.single.type, TxnType.expense);
    expect(txns.single.categoryId, food.id);
    expect(txns.single.currency, 'USD');

    // Home reflects the new expense and the reduced balance.
    await pumpUntil(tester, find.text(r'$12.00'));
    await pumpUntil(tester, find.text(r'$88.00'));

    await _dispose(tester, db);
  });

  testWidgets('minus button: amount first, category picked on save', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (db, repos) = await _setup();
    final transport = (await repos.categories.getAll()).firstWhere((c) => c.name == 'Transport');

    await tester.pumpWidget(_app(db));
    await pumpUntil(tester, find.byKey(const Key('home-add-expense')));
    await tester.tap(find.byKey(const Key('home-add-expense')));
    await pumpUntil(tester, find.byKey(const Key('save-button')));
    await tester.pump(const Duration(seconds: 1)); // let the page transition finish

    // Calculator: 10 + 5.5 = 15.50
    for (final k in ['key-1', 'key-0', 'key-add', 'key-5', 'key-dot', 'key-5']) {
      await tester.tap(find.byKey(Key(k)));
    }
    await tester.pump();
    expect(find.text(r'= $15.50'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-button')));
    final pick = find.byKey(Key('pick-category-${transport.id}'));
    await pumpUntil(tester, pick);
    await tester.pump(const Duration(seconds: 1)); // sheet slide-in
    await tester.tap(pick);
    await pumpUntil(tester, find.byKey(const Key('home-add-expense')));
    await tester.pump(const Duration(milliseconds: 500));

    final txns = (await tester.runAsync(() => repos.transactions.query(const TxnFilter())))!;
    expect(txns.single.amount, 1550);
    expect(txns.single.categoryId, transport.id);

    await _dispose(tester, db);
  });

  testWidgets('empty amount is rejected and nothing is saved', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (db, repos) = await _setup();
    await tester.pumpWidget(_app(db));
    await pumpUntil(tester, find.byKey(const Key('home-add-income')));
    await tester.tap(find.byKey(const Key('home-add-income')));
    await pumpUntil(tester, find.byKey(const Key('save-button')));
    await tester.pump(const Duration(seconds: 1)); // let the page transition finish
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter an amount greater than zero'), findsWidgets);
    expect(await tester.runAsync(() => repos.transactions.count()), 0);

    await _dispose(tester, db);
  });

  testWidgets('first launch: skip intro, create first account, land on home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (db, _) = await _setup(onboarded: false);
    await tester.pumpWidget(_app(db));
    await pumpUntil(tester, find.byKey(const Key('onboarding-skip')));
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await pumpUntil(tester, find.byKey(const Key('setup-finish')));
    await tester.tap(find.byKey(const Key('setup-finish')));
    await pumpUntil(tester, find.byKey(const Key('home-add-expense')));

    final accounts = (await tester.runAsync(() => DriftAccountRepository(db).getAll()))!;
    expect(accounts, hasLength(1));
    final settings = (await tester.runAsync(() => DriftSettingsRepository(db).get()))!;
    expect(settings.onboardingDone, isTrue);
    expect(settings.defaultAccountId, accounts.single.id);

    await _dispose(tester, db);
  });
}
