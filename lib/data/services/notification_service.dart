import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-only notifications (no push, no server). Permission is requested
/// only when the user turns on a reminder or budget alert.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _budgetChannel = AndroidNotificationDetails(
    'budget_alerts',
    'Budget alerts',
    channelDescription: 'Alerts when a budget reaches 80% or 100%',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _reminderChannel = AndroidNotificationDetails(
    'recurring_reminders',
    'Bill reminders',
    channelDescription: 'Reminders before a recurring transaction is due',
    importance: Importance.defaultImportance,
  );
  static const _darwin = DarwinNotificationDetails();

  static int budgetAlertId(int budgetId) => 1000000 + budgetId;
  static int reminderId(int ruleId) => 2000000 + ruleId;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (_initialized || !_supported) return;
    // Timezone database is bundled with the package; no download happens.
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Asks the OS for notification permission. Returns whether it is granted.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  Future<void> showBudgetAlert({
    required int budgetId,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await init();
    await _plugin.show(
      id: budgetAlertId(budgetId),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _budgetChannel, iOS: _darwin),
    );
  }

  /// Schedules a one-shot reminder at local time [when]. Past times are
  /// ignored. Uses inexact alarms so no exact-alarm permission is needed.
  Future<void> scheduleReminder({
    required int ruleId,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await init();
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: reminderId(ruleId),
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: const NotificationDetails(android: _reminderChannel, iOS: _darwin),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  /// Cancels scheduled reminders whose rule is not in [ruleIds] — e.g. rules
  /// removed by a restore or by deleting their account/category.
  Future<void> cancelRemindersExcept(Set<int> ruleIds) async {
    if (!_supported) return;
    await init();
    final keep = ruleIds.map(reminderId).toSet();
    for (final p in await _plugin.pendingNotificationRequests()) {
      final isReminder = p.id >= reminderId(0) && p.id < reminderId(0) + 1000000;
      if (isReminder && !keep.contains(p.id)) await _plugin.cancel(id: p.id);
    }
  }

  Future<void> cancelReminder(int ruleId) async {
    if (!_supported) return;
    await init();
    await _plugin.cancel(id: reminderId(ruleId));
  }
}
