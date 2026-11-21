import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes the current balance to the home-screen widget. The widget reads
/// the values from local shared storage; no network involved.
class HomeWidgetService {
  const HomeWidgetService();

  static const androidProvider = 'BalanceWidgetProvider';
  static const iosKind = 'PennyfoldWidget';
  static const iosAppGroup = 'group.com.pennyfold.app';

  /// URIs the widget uses to open the app.
  static const addExpenseUri = 'pennyfold://add?type=expense';
  static const addIncomeUri = 'pennyfold://add?type=income';

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(iosAppGroup);
    } catch (_) {}
  }

  Future<void> update({required String balanceLabel, required String balance}) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>('balance_label', balanceLabel);
      await HomeWidget.saveWidgetData<String>('balance', balance);
      await HomeWidget.updateWidget(androidName: androidProvider, iOSName: iosKind);
    } catch (_) {
      // Widget not installed / not supported on this platform: ignore.
    }
  }

  Future<Uri?> initialLaunchUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  Stream<Uri?> get clicks => HomeWidget.widgetClicked;
}
