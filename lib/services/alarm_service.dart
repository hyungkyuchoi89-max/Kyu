import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/day_alarm.dart';
import '../models/study_plan.dart';
import 'settings_service.dart';

typedef AlarmTapCallback = void Function();

/// 요일별 반복 알람을 예약하고, 알림 탭을 앱 화면과 연결한다.
///
/// Android
/// - `flutter_local_notifications`의 exact alarm + full-screen intent로 예약한다.
/// - 알림 소리는 `res/raw/alarm.wav`이고, 앱이 열리면 기기 기본 알람음도 함께 울린다.
///
/// iOS
/// - Apple은 잠금 화면에서 앱이 임의로 소리를 계속 재생하는 것을 허용하지 않는다.
///   그래서 알람이 울린 뒤 30초 간격의 연속 알림(chain)을 미리 예약해 두고,
///   사용자가 알림을 눌러 앱에 들어오면 남은 연속 알림을 즉시 취소한다.
/// - 앱에 들어온 뒤 퀴즈를 통과하기 전에 앱을 벗어나면 5초 뒤 다시 울리는
///   알림을 예약해 알람을 우회하지 못하게 한다.
class AlarmService {
  AlarmService();

  static const String channelId = 'wordwake_alarm_v1';
  static const String channelName = 'WordWake 단어 알람';
  static const String channelDescription = 'WordWake 영어단어 알람';
  static const String payloadAlarm = 'wordwake.alarm';

  static const int _notificationIdBase = 100;

  /// iOS 연속 알림(chain)의 알림 ID 대역
  static const int _iosChainBaseId = 900;
  static const int iosChainCount = 10;
  static const Duration iosChainInterval = Duration(seconds: 30);

  /// iOS에서 앱을 벗어났을 때 다시 울리는 알림 ID
  static const int _iosBypassId = 950;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _launchedFromAlarm = false;
  AlarmTapCallback? onAlarmTap;

  bool get isInitialized => _initialized;
  bool get launchedFromAlarm => _launchedFromAlarm;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tzdata.initializeTimeZones();
    await _configureLocalTimeZone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final NotificationAppLaunchDetails? launchDetails =
        await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload == payloadAlarm) {
      _launchedFromAlarm = true;
    }

    _initialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 이름을 해석하지 못하면 기기 오프셋에 가장 가까운 시간대를 쓴다.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (_) {
        // 그래도 실패하면 timezone 패키지 기본(UTC)을 유지한다.
      }
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == payloadAlarm) {
      _launchedFromAlarm = true;
      onAlarmTap?.call();
    }
  }

  /// Android 13+ 알림 권한과 정확한 알람 권한을 요청한다.
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    bool granted = true;
    try {
      final bool? notificationGranted = await android.requestNotificationsPermission();
      if (notificationGranted == false) {
        granted = false;
      }
    } catch (_) {
      granted = false;
    }
    try {
      await android.requestExactAlarmsPermission();
    } catch (_) {
      // 사용자가 설정에서 직접 허용할 수 있다.
    }
    return granted;
  }

  Future<bool> canScheduleExact() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 설정에 맞춰 모든 요일 알람을 다시 예약한다.
  Future<void> rescheduleAll(SettingsService settings) async {
    await _plugin.cancelAll();
    for (final DayAlarm alarm in settings.alarms) {
      if (!alarm.enabled || !settings.plan.isActiveWeekday(alarm.weekday)) {
        continue;
      }
      await _scheduleWeekly(alarm);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 오늘 울린 알림을 내리고, 같은 요일의 다음 주 알람은 다시 예약한다.
  ///
  /// 알림을 단순히 cancel하면 그 요일의 반복 예약까지 사라지기 때문에
  /// 다시 예약해 주는 것이 중요하다.
  Future<void> stopRingingNotification(SettingsService settings) async {
    final int weekday = DateTime.now().weekday;
    await _plugin.cancel(_notificationIdBase + weekday);
    await cancelIosAlarmChain();
    final DayAlarm alarm = settings.alarmFor(weekday);
    if (alarm.enabled && settings.plan.isActiveWeekday(weekday)) {
      await _scheduleWeekly(alarm);
    }
  }

  Future<void> _scheduleWeekly(DayAlarm alarm) async {
    await _plugin.zonedSchedule(
      _notificationIdBase + alarm.weekday,
      'WordWake',
      '${alarm.label}요일 ${alarm.timeLabel} · 단어 퀴즈로 아침을 시작해요',
      _nextInstanceOfWeekday(alarm.weekday, alarm.hour, alarm.minute),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payloadAlarm,
    );
  }

  /// iOS: 알람이 울린 뒤 30초마다 다시 울리는 알림을 예약한다.
  Future<void> startIosAlarmChain() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await cancelIosAlarmChain();
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    for (int index = 0; index < iosChainCount; index++) {
      await _plugin.zonedSchedule(
        _iosChainBaseId + index,
        'WordWake',
        '단어 퀴즈를 풀어야 알람이 꺼져요',
        now.add(iosChainInterval * (index + 1)),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payloadAlarm,
      );
    }
  }

  /// iOS: 예약해 둔 연속 알림을 모두 취소한다.
  Future<void> cancelIosAlarmChain() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    for (int index = 0; index < iosChainCount; index++) {
      await _plugin.cancel(_iosChainBaseId + index);
    }
    await _plugin.cancel(_iosBypassId);
  }

  /// iOS: 퀴즈를 통과하기 전에 앱을 벗어났을 때 5초 뒤 다시 울린다.
  Future<void> scheduleIosBypassAlert() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await _plugin.zonedSchedule(
      _iosBypassId,
      'WordWake 알람이 아직 꺼지지 않았어요',
      '단어 퀴즈를 풀어야 오늘의 알람이 끝납니다',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payloadAlarm,
    );
  }

  NotificationDetails _notificationDetails() {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
    );
    const DarwinNotificationDetails darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
      sound: 'default',
      // 잠금 화면에서도 집중 모드를 뚫고 표시되도록 Time-Sensitive로 보낸다.
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: android, iOS: darwin);
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    int guard = 0;
    while ((scheduled.weekday != weekday || !scheduled.isAfter(now)) && guard < 14) {
      scheduled = scheduled.add(const Duration(days: 1));
      guard++;
    }
    return scheduled;
  }

  /// 다음에 울릴 알람 시각. 플랜에서 쉬는 요일은 건너뛴다.
  DateTime? nextAlarm(List<DayAlarm> alarms, StudyPlan plan, {DateTime? from}) {
    final DateTime now = from ?? DateTime.now();
    DateTime? best;
    for (final DayAlarm alarm in alarms) {
      if (!alarm.enabled || !plan.isActiveWeekday(alarm.weekday)) {
        continue;
      }
      DateTime candidate = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      int guard = 0;
      while ((candidate.weekday != alarm.weekday || !candidate.isAfter(now)) && guard < 14) {
        candidate = candidate.add(const Duration(days: 1));
        guard++;
      }
      if (best == null || candidate.isBefore(best)) {
        best = candidate;
      }
    }
    return best;
  }
}
