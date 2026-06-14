import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Default to local timezone based on device settings
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {

      },
    );

    // Request permissions (Android 13+)
    if (Platform.isAndroid) {
      final bool? granted = await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      print('DEBUG: Notification permission granted: $granted');

      final bool? alarmGranted = await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
          
      print('DEBUG: Exact Alarms permission granted: $alarmGranted');
    }

    _initialized = true;
  }

  Future<void> checkAndScheduleDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    if (isEnabled) {
      await scheduleDailyReminder(hour: 19, minute: 00);
    } else {
      await cancelAll();
    }
  }

  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await cancelAll(); // Ensure we don't stack multiple daily reminders

    // Config
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Tägliche Erinnerung',
      channelDescription: 'Erinnert dich an dein tägliches Vokabeltraining',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Calculate next occurrence
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

    print('DEBUG: Scheduling daily reminder for: $scheduledDate');

    await _localNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Zeit zum Lernen! 🧠',
      'Dein Vokabeltrainer wartet auf dich. Bleib am Ball für deinen Streak!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
    );
    print('DEBUG: Reminder scheduled successfully.');
  }

  Future<void> scheduleTestReminder() async {
    await cancelAll();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Tägliche Erinnerung',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Schedule 10 seconds from now for immediate testing
    tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

    await _localNotificationsPlugin.zonedSchedule(
      0,
      'Test Erinnerung 🎯',
      'Das ist eine Test-Benachrichtigung für die App.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _localNotificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
