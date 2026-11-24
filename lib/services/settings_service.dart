import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_alarm.dart';
import '../models/study_plan.dart';
import '../models/word_level.dart';

/// 사용자 설정(플랜, 레벨, 학습 속도, 요일별 알람)을 보관한다.
///
/// 값이 바뀌면 [notifyListeners]로 화면에 알리고 즉시 기기에 저장한다.
class SettingsService extends ChangeNotifier {
  static const String _keyPlan = 'ww.plan';
  static const String _keyLevel = 'ww.level';
  static const String _keyStudySeconds = 'ww.studySeconds';
  static const String _keyAlarms = 'ww.dayAlarms';
  static const String _keyOnboarding = 'ww.onboardingDone';

  StudyPlan _plan = StudyPlan.easy;
  WordLevel _level = WordLevel.elementary;
  int _studySeconds = 3;
  List<DayAlarm> _alarms = DayAlarm.defaults();
  bool _onboardingDone = false;

  StudyPlan get plan => _plan;
  WordLevel get level => _level;
  int get studySeconds => _studySeconds;
  List<DayAlarm> get alarms => List<DayAlarm>.unmodifiable(_alarms);
  bool get onboardingDone => _onboardingDone;

  /// 실제로 알람이 예약되는 요일이 하나라도 있는지.
  bool get hasEnabledAlarm => _alarms.any(
        (DayAlarm alarm) => alarm.enabled && _plan.isActiveWeekday(alarm.weekday),
      );

  DayAlarm alarmFor(int weekday) {
    for (final DayAlarm alarm in _alarms) {
      if (alarm.weekday == weekday) {
        return alarm;
      }
    }
    return DayAlarm(weekday: weekday, hour: 7, minute: 0, enabled: false);
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _plan = StudyPlan.fromKey(prefs.getString(_keyPlan));
    _level = WordLevel.fromKey(prefs.getString(_keyLevel));
    final int? seconds = prefs.getInt(_keyStudySeconds);
    if (seconds != null) {
      _studySeconds = seconds.clamp(1, 5).toInt();
    }
    final String? rawAlarms = prefs.getString(_keyAlarms);
    if (rawAlarms != null) {
      try {
        final Object? decoded = jsonDecode(rawAlarms);
        if (decoded is List<dynamic>) {
          final List<DayAlarm> parsed = decoded
              .whereType<Map<String, dynamic>>()
              .map(DayAlarm.fromJson)
              .toList();
          if (parsed.length == 7) {
            parsed.sort((DayAlarm a, DayAlarm b) => a.weekday.compareTo(b.weekday));
            _alarms = parsed;
          }
        }
      } catch (_) {
        _alarms = DayAlarm.defaults();
      }
    }
    _onboardingDone = prefs.getBool(_keyOnboarding) ?? false;
    notifyListeners();
  }

  Future<void> setPlan(StudyPlan plan) async {
    if (_plan == plan) {
      return;
    }
    _plan = plan;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlan, plan.key);
  }

  Future<void> setLevel(WordLevel level) async {
    if (_level == level) {
      return;
    }
    _level = level;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLevel, level.key);
  }

  Future<void> setStudySeconds(int seconds) async {
    final int value = seconds.clamp(1, 5).toInt();
    if (_studySeconds == value) {
      return;
    }
    _studySeconds = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStudySeconds, value);
  }

  Future<void> setAlarmEnabled(int weekday, bool enabled) async {
    _alarms = _alarms
        .map((DayAlarm alarm) =>
            alarm.weekday == weekday ? alarm.copyWith(enabled: enabled) : alarm)
        .toList();
    notifyListeners();
    await _saveAlarms();
  }

  Future<void> setAlarmTime(int weekday, int hour, int minute) async {
    _alarms = _alarms
        .map((DayAlarm alarm) => alarm.weekday == weekday
            ? alarm.copyWith(hour: hour, minute: minute)
            : alarm)
        .toList();
    notifyListeners();
    await _saveAlarms();
  }

  Future<void> markOnboardingDone() async {
    if (_onboardingDone) {
      return;
    }
    _onboardingDone = true;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  Future<void> _saveAlarms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      _alarms.map((DayAlarm alarm) => alarm.toJson()).toList(),
    );
    await prefs.setString(_keyAlarms, raw);
  }
}
