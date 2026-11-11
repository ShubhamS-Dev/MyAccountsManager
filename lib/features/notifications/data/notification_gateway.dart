import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';

/// Device-level notification state shown in settings and the Activity center.
class NotificationStatus {
  const NotificationStatus({
    required this.supported,
    required this.permitted,
    required this.exactTiming,
  });

  static const unsupported = NotificationStatus(
    supported: false,
    permitted: false,
    exactTiming: false,
  );

  /// False where the app cannot post notifications (tests, non-Android).
  final bool supported;

  /// The user allows this app to post notifications.
  final bool permitted;

  /// Alarms & reminders access is granted, so reminders fire on the minute.
  final bool exactTiming;
}

/// Boundary between the app and the OS notification system.
abstract class NotificationGateway {
  bool get supported;

  /// Prepares channels and time zones. [onOpen] receives the in-app route of
  /// a tapped notification while the app is running.
  Future<void> initialize({required void Function(String route) onOpen});

  /// Route of the notification that launched the app, if any.
  Future<String?> launchRoute();

  Future<NotificationStatus> status();

  /// Shows the Android 13+ system prompt. Returns whether it is now allowed.
  Future<bool> requestPermission();

  /// Opens the system Alarms & reminders screen for this app.
  Future<void> requestExactTiming();

  /// Opens this app's notification settings.
  Future<void> openSettings();

  /// Makes the pending notifications match [reminders] exactly.
  Future<void> replaceSchedule(List<PlannedReminder> reminders);

  Future<void> showTest({required String title, required String body});
}

/// Used in tests and on platforms without notification support.
class NoopNotificationGateway implements NotificationGateway {
  const NoopNotificationGateway();

  @override
  bool get supported => false;

  @override
  Future<void> initialize({required void Function(String route) onOpen}) =>
      Future.value();

  @override
  Future<String?> launchRoute() => Future.value();

  @override
  Future<NotificationStatus> status() =>
      Future.value(NotificationStatus.unsupported);

  @override
  Future<bool> requestPermission() => Future.value(false);

  @override
  Future<void> requestExactTiming() => Future.value();

  @override
  Future<void> openSettings() => Future.value();

  @override
  Future<void> replaceSchedule(List<PlannedReminder> reminders) =>
      Future.value();

  @override
  Future<void> showTest({required String title, required String body}) =>
      Future.value();
}

/// Android implementation backed by flutter_local_notifications.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'MyKhata due dates, overdue entries and scheduled transactions';
  static const _testId = 1;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;
  Future<void> _queue = Future.value();
  String? _lastSchedule;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<void> initialize({required void Function(String route) onOpen}) {
    return _initialized ??= _initialize(onOpen);
  }

  Future<void> _initialize(void Function(String route) onOpen) async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(await _deviceLocation());
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) onOpen(route);
      },
    );
  }

  /// The device's IANA zone, else any zone matching the current UTC offset.
  static Future<tz.Location> _deviceLocation() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(info.identifier);
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      return tz.timeZoneDatabase.locations.values.firstWhere(
        (location) => location.currentTimeZone.offset == offset,
        orElse: () => tz.UTC,
      );
    }
  }

  @override
  Future<String?> launchRoute() async {
    await _initialized;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final route = details!.notificationResponse?.payload;
    return route != null && route.startsWith('/') ? route : null;
  }

  @override
  Future<NotificationStatus> status() async {
    await _initialized;
    final android = _android;
    if (android == null) return NotificationStatus.unsupported;
    return NotificationStatus(
      supported: true,
      permitted: await android.areNotificationsEnabled() ?? false,
      exactTiming: await android.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _initialized;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> requestExactTiming() async {
    await _initialized;
    await _android?.requestExactAlarmsPermission();
    // Timing mode may have changed; force the next replace to reschedule.
    _lastSchedule = null;
  }

  @override
  Future<void> openSettings() async {
    await _initialized;
    await _android?.openAppNotificationSettings();
  }

  @override
  Future<void> replaceSchedule(List<PlannedReminder> reminders) {
    // Serialise so overlapping database updates cannot interleave.
    return _queue = _queue.then((_) => _replace(reminders));
  }

  Future<void> _replace(List<PlannedReminder> reminders) async {
    try {
      await _initialized;
      final now = DateTime.now();
      final pending = [
        for (final reminder in reminders)
          if (reminder.fireAt.isAfter(now)) reminder,
      ];
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final signature = [
        exact,
        for (final reminder in pending) reminder.hashCode,
      ].join(',');
      if (signature == _lastSchedule) return;

      // Clears only reminders not yet shown; delivered ones stay visible.
      await _plugin.cancelAllPendingNotifications();
      for (final reminder in pending) {
        final fireAt = reminder.fireAt;
        await _plugin.zonedSchedule(
          id: reminder.id,
          scheduledDate: tz.TZDateTime(
            tz.local,
            fireAt.year,
            fireAt.month,
            fireAt.day,
            fireAt.hour,
            fireAt.minute,
          ),
          notificationDetails: _details(reminder.body),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          title: reminder.title,
          body: reminder.body,
          payload: reminder.route,
        );
      }
      _lastSchedule = signature;
    } catch (error) {
      // Never log reminder text: it can contain names and amounts.
      _lastSchedule = null;
      debugPrint('Reminder scheduling failed: ${error.runtimeType}');
    }
  }

  @override
  Future<void> showTest({required String title, required String body}) async {
    await _initialized;
    await _plugin.show(
      id: _testId,
      title: title,
      body: body,
      notificationDetails: _details(body),
      payload: '/activity',
    );
  }

  static NotificationDetails _details(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(body),
    ),
  );
}
