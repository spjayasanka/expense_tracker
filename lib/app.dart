import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/entities/app_settings.dart';
import 'presentation/actions.dart';
import 'presentation/l10n.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/lock/app_lock.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/startup.dart';
import 'presentation/theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class PennyfoldApp extends ConsumerWidget {
  const PennyfoldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final settings = settingsAsync.value;
    final themeMode = switch (settings?.themeMode ?? AppThemeMode.system) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp(
      onGenerateTitle: (ctx) => ctx.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      home: settings == null
          ? const _Splash()
          : settings.onboardingDone
              ? StartupTasks(navigatorKey: _navigatorKey, child: const HomeScreen())
              : const OnboardingScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Icon(Icons.eco, size: 72, color: Theme.of(context).colorScheme.primary),
        ),
      );
}
