import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 알람의 소리와 진동을 따로 제어한다.
///
/// 상태 변화:
/// 1. 알람 발생 → [start] : 소리 + 진동
/// 2. 학습/시험 시작 → [muteSound] : 소리만 끄고 진동은 유지
/// 3. 퀴즈 통과 후 해지 → [stop] : 진동까지 완전히 정지
///
/// Android에서는 네이티브 채널(`wordwake/ringtone`)로 기기 기본 알람음
/// (`RingtoneManager.TYPE_ALARM`)을 무한 반복 재생하고, 기기 기본음이 없거나
/// iOS라면 앱에 포함된 `assets/audio/alarm.wav`를 반복 재생한다.
class RingtoneService {
  RingtoneService._();

  static final RingtoneService instance = RingtoneService._();

  static const MethodChannel _channel = MethodChannel('wordwake/ringtone');

  final AudioPlayer _player = AudioPlayer();
  Timer? _vibrationTimer;
  bool _active = false;
  bool _soundPlaying = false;

  /// 소리 또는 진동이 하나라도 살아 있는지.
  bool get isActive => _active;

  bool get isSoundPlaying => _soundPlaying;

  /// 알람 시작: 소리와 진동을 함께 켠다.
  Future<void> start() async {
    if (_active) {
      return;
    }
    _active = true;
    _startVibration();
    await _startSound();
  }

  /// 학습/시험으로 넘어갈 때: 소리만 끄고 진동은 계속 유지한다.
  Future<void> muteSound() async {
    if (!_soundPlaying) {
      return;
    }
    await _stopSound();
  }

  /// 해지: 소리와 진동을 모두 멈춘다.
  Future<void> stop() async {
    _active = false;
    _soundPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    await _stopSound();
  }

  Future<void> _startSound() async {
    bool systemTone = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bool? result = await _channel.invokeMethod<bool>('playSystemAlarm');
        systemTone = result ?? false;
      } catch (error) {
        systemTone = false;
        debugPrint('기기 기본 알람음을 재생할 수 없습니다: $error');
      }
    }

    if (systemTone) {
      _soundPlaying = true;
      return;
    }

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('audio/alarm.wav'));
      _soundPlaying = true;
    } catch (error) {
      debugPrint('알람 음원을 재생하지 못했습니다: $error');
      _soundPlaying = false;
    }
  }

  Future<void> _stopSound() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<bool>('stop');
      } catch (_) {
        // 이미 멈췄거나 채널이 없을 수 있다.
      }
    }
    try {
      await _player.stop();
    } catch (_) {
      // 재생 중이 아니면 무시한다.
    }
  }

  void _startVibration() {
    _vibrationTimer?.cancel();
    HapticFeedback.heavyImpact();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1400), (Timer timer) {
      if (!_active) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
    });
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
