import 'package:flutter/material.dart';

/// 월요일부터 일요일까지의 짧은 요일 이름.
const List<String> kWeekdayLabels = <String>['월', '화', '수', '목', '금', '토', '일'];

String weekdayLabel(int weekday) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    return '';
  }
  return kWeekdayLabels[weekday - 1];
}

String formatTime(TimeOfDay time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatHourMinute(int hour, int minute) {
  final String h = hour.toString().padLeft(2, '0');
  final String m = minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// 요일별 알람 설정 한 건.
class DayAlarm {
  const DayAlarm({
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  /// DateTime.monday(1) ~ DateTime.sunday(7)
  final int weekday;
  final int hour;
  final int minute;
  final bool enabled;

  String get label => weekdayLabel(weekday);

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  String get timeLabel => formatHourMinute(hour, minute);

  DayAlarm copyWith({int? weekday, int? hour, int? minute, bool? enabled}) {
    return DayAlarm(
      weekday: weekday ?? this.weekday,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      };

  factory DayAlarm.fromJson(Map<String, dynamic> json) {
    return DayAlarm(
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      hour: (json['hour'] as num?)?.toInt() ?? 7,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      enabled: (json['enabled'] as bool?) ?? false,
    );
  }

  /// 기본값: 월~금 07:00 켜짐, 토~일 08:00 꺼짐.
  static List<DayAlarm> defaults() {
    return List<DayAlarm>.generate(7, (int index) {
      final int weekday = index + 1;
      final bool weekend = weekday >= DateTime.saturday;
      return DayAlarm(
        weekday: weekday,
        hour: weekend ? 8 : 7,
        minute: 0,
        enabled: !weekend,
      );
    }, growable: false);
  }
}
