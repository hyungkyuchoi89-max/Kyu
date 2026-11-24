package com.wordwake.word_alarm_app

import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * WordWake Android 진입점.
 *
 * 알람이 울릴 때 Dart 쪽에서 `wordwake/ringtone` 채널로 기기 기본 알람음
 * (RingtoneManager.TYPE_ALARM)을 무한 반복 재생하도록 연결한다.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "wordwake/ringtone"
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSystemAlarm" -> result.success(playSystemAlarm())
                    "stop" -> {
                        stopRingtone()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 기기 기본 알람음을 알람 볼륨/알람 용도로 재생한다. 재생에 성공하면 true. */
    private fun playSystemAlarm(): Boolean {
        stopRingtone()

        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: return false

        return try {
            val tone = RingtoneManager.getRingtone(applicationContext, uri) ?: return false
            tone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                tone.isLooping = true
            }
            tone.play()
            ringtone = tone
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun stopRingtone() {
        try {
            ringtone?.stop()
        } catch (_: Exception) {
            // 이미 멈춘 경우 무시한다.
        }
        ringtone = null
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }
}
