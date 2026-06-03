import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LearningReminderState {
  const LearningReminderState({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.isBusy = false,
    this.lastError,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final bool isBusy;
  final String? lastError;

  LearningReminderState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? isBusy,
    String? lastError,
  }) {
    return LearningReminderState(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isBusy: isBusy ?? this.isBusy,
      lastError: lastError,
    );
  }
}

class LearningReminderNotifier extends StateNotifier<LearningReminderState> {
  LearningReminderNotifier(this._prefs)
    : super(
        LearningReminderState(
          enabled: _prefs.getBool(_enabledKey) ?? false,
          hour: _prefs.getInt(_hourKey) ?? 20,
          minute: _prefs.getInt(_minuteKey) ?? 0,
        ),
      );

  static const String _enabledKey = 'learning_reminders_enabled';
  static const String _hourKey = 'learning_reminders_hour';
  static const String _minuteKey = 'learning_reminders_minute';
  static const int _dailyReminderId = 7301;
  static const String _channelId = 'learning_reminders';
  static const String _channelName = 'Learning reminders';
  static const String _channelDescription = 'Daily reminders to keep learning';

  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Almaty'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
    _initialized = true;
  }

  Future<bool> setEnabled({
    required bool enabled,
    required String title,
    required String body,
  }) async {
    state = state.copyWith(isBusy: true);
    try {
      await initialize();
      if (enabled) {
        final bool allowed = await _requestPermission();
        if (!allowed) {
          state = state.copyWith(
            enabled: false,
            isBusy: false,
            lastError: 'permission_denied',
          );
          await _prefs.setBool(_enabledKey, false);
          return false;
        }
        await _scheduleDaily(title: title, body: body);
      } else {
        await _notifications.cancel(id: _dailyReminderId);
      }

      await _prefs.setBool(_enabledKey, enabled);
      state = state.copyWith(enabled: enabled, isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      return false;
    }
  }

  Future<bool> setTime({
    required TimeOfDay time,
    required String title,
    required String body,
  }) async {
    state = state.copyWith(isBusy: true);
    try {
      await _prefs.setInt(_hourKey, time.hour);
      await _prefs.setInt(_minuteKey, time.minute);
      state = state.copyWith(hour: time.hour, minute: time.minute);
      if (state.enabled) {
        await initialize();
        await _scheduleDaily(title: title, body: body);
      }
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      return false;
    }
  }

  Future<bool> showPreview({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      final bool allowed = await _requestPermission();
      if (!allowed) return false;
      await _notifications.show(
        id: _dailyReminderId + 1,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final MacOSFlutterLocalNotificationsPlugin? macPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await macPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    return true;
  }

  Future<void> _scheduleDaily({
    required String title,
    required String body,
  }) async {
    await _notifications.cancel(id: _dailyReminderId);
    await _notifications.zonedSchedule(
      id: _dailyReminderId,
      title: title,
      body: body,
      scheduledDate: _nextReminderTime(),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  tz.TZDateTime _nextReminderTime() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      state.hour,
      state.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final StateNotifierProvider<LearningReminderNotifier, LearningReminderState>
learningReminderProvider =
    StateNotifierProvider<LearningReminderNotifier, LearningReminderState>(
      (Ref ref) => throw UnimplementedError(
        'learningReminderProvider must be overridden in ProviderScope',
      ),
    );
