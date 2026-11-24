import 'package:flutter/material.dart';

import 'app.dart';
import 'services/alarm_service.dart';
import 'services/settings_service.dart';
import 'services/word_progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SettingsService settings = SettingsService();
  await settings.load();

  // 단어별 오답 기록(반복 학습 가중치)을 불러온다.
  await WordProgressService.instance.load();

  final AlarmService alarmService = AlarmService();
  await alarmService.initialize();

  // 앱을 다시 열 때마다 설정대로 알람을 맞춰 둔다(재부팅/업데이트 후에도 유지).
  if (settings.hasEnabledAlarm) {
    try {
      await alarmService.rescheduleAll(settings);
    } catch (error) {
      debugPrint('알람 예약에 실패했습니다: $error');
    }
  }

  runApp(WordWakeApp(settings: settings, alarmService: alarmService));
}
