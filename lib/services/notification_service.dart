import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _bedtimeId = 1001;
  static const String _channelId = 'somnkoll_bedtime';
  static const String _bedtimeHourKey = 'bedtime_hour';
  static const String _bedtimeMinuteKey = 'bedtime_minute';
  static const String _bedtimeEnabledKey = 'bedtime_enabled';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(init);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<TimeOfDay> getBedtime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_bedtimeHourKey) ?? 22,
      minute: prefs.getInt(_bedtimeMinuteKey) ?? 30,
    );
  }

  Future<bool> isBedtimeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bedtimeEnabledKey) ?? false;
  }

  Future<void> setBedtime(TimeOfDay time, {required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bedtimeHourKey, time.hour);
    await prefs.setInt(_bedtimeMinuteKey, time.minute);
    await prefs.setBool(_bedtimeEnabledKey, enabled);
    if (enabled) {
      await scheduleBedtimeReminder(time);
    } else {
      await cancelBedtimeReminder();
    }
  }

  Future<void> scheduleBedtimeReminder(TimeOfDay time) async {
    await initialize();
    await _plugin.cancel(_bedtimeId);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        _bedtimeId,
        'Dags att sova 🌙',
        'Starta sömnspårning så vaknar du utvilad imorgon.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Läggdagspåminnelse',
            channelDescription: 'Daglig påminnelse om att starta sömnspårning',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('[Notif] schedule failed: $e');
    }
  }

  Future<void> cancelBedtimeReminder() async {
    await initialize();
    await _plugin.cancel(_bedtimeId);
  }
}
