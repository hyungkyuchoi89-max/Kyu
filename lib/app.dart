import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/ring_screen.dart';
import 'services/alarm_service.dart';
import 'services/settings_service.dart';

class WordWakeApp extends StatefulWidget {
  const WordWakeApp({
    super.key,
    required this.settings,
    required this.alarmService,
  });

  final SettingsService settings;
  final AlarmService alarmService;

  @override
  State<WordWakeApp> createState() => _WordWakeAppState();
}

class _WordWakeAppState extends State<WordWakeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _ringScreenOpen = false;

  @override
  void initState() {
    super.initState();
    widget.alarmService.onAlarmTap = _openRingScreenFromAlarm;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.alarmService.launchedFromAlarm) {
        _openRingScreenFromAlarm();
      }
    });
  }

  void _openRingScreenFromAlarm() {
    if (_ringScreenOpen) {
      return;
    }
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _ringScreenOpen = true;
    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => RingScreen(
              settings: widget.settings,
              alarmService: widget.alarmService,
              source: RingSource.alarm,
              onClosed: () => _ringScreenOpen = false,
            ),
            fullscreenDialog: true,
          ),
        )
        .whenComplete(() => _ringScreenOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordWake',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildAppTheme(),
      home: HomeScreen(
        settings: widget.settings,
        alarmService: widget.alarmService,
      ),
    );
  }
}
