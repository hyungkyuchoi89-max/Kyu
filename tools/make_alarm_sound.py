"""WordWake 알람 음원(assets/audio/alarm.wav)을 만든다.

표준 라이브러리 wave 모듈만 사용한다.
실행: python3 tools/make_alarm_sound.py
"""

import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'audio', 'alarm.wav')
RAW_COPY = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw', 'alarm.wav')

SAMPLE_RATE = 44100
DURATION = 2.4

# (시작 초, 길이 초, 주파수 Hz)
BEEPS = [
    (0.00, 0.28, 880.0),
    (0.36, 0.28, 1046.5),
    (0.72, 0.28, 1318.5),
    (1.20, 0.28, 880.0),
    (1.56, 0.28, 1046.5),
    (1.92, 0.30, 1318.5),
]


def envelope(local_time, length):
    attack = 0.012
    release = 0.06
    if local_time < attack:
        return local_time / attack
    if local_time > length - release:
        return max(0.0, (length - local_time) / release)
    return 1.0


def main():
    total_samples = int(SAMPLE_RATE * DURATION)
    samples = [0.0] * total_samples

    for start, length, freq in BEEPS:
        start_index = int(start * SAMPLE_RATE)
        count = int(length * SAMPLE_RATE)
        for i in range(count):
            t = i / SAMPLE_RATE
            env = envelope(t, length)
            # 기본음 + 2배음으로 조금 더 또렷한 알람 소리를 만든다.
            value = (math.sin(2 * math.pi * freq * t) * 0.75 +
                     math.sin(2 * math.pi * freq * 2 * t) * 0.18 +
                     math.sin(2 * math.pi * freq * 3 * t) * 0.07)
            index = start_index + i
            if index < total_samples:
                samples[index] += value * env * 0.55

    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames.extend(struct.pack('<h', int(clipped * 32767)))

    os.makedirs(os.path.dirname(ASSET), exist_ok=True)
    with wave.open(ASSET, 'wb') as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print('wrote', ASSET)

    os.makedirs(os.path.dirname(RAW_COPY), exist_ok=True)
    with open(ASSET, 'rb') as src, open(RAW_COPY, 'wb') as dst:
        dst.write(src.read())
    print('wrote', RAW_COPY)


if __name__ == '__main__':
    main()
