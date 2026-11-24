"""WordWake Android 런처 아이콘을 PNG로 생성한다.

외부 이미지 라이브러리 없이 표준 라이브러리(zlib, struct)만 사용한다.
실행: python3 tools/make_icons.py
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

NAVY = (0x12, 0x18, 0x26)
ACCENT = (0xFB, 0xBF, 0x24)

# 알파벳 W를 이루는 꺾은선 (0~1 정규화 좌표)
W_POINTS = [
    (0.30, 0.40),
    (0.385, 0.62),
    (0.50, 0.455),
    (0.615, 0.62),
    (0.70, 0.40),
]
W_THICKNESS = 0.05


def _chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data +
            struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)
    png = b'\x89PNG\r\n\x1a\n'
    png += _chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    png += _chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += _chunk(b'IEND', b'')
    with open(path, 'wb') as handle:
        handle.write(png)


def _segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    if length_sq == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = ((px - ax) * dx + (py - ay) * dy) / length_sq
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def _rounded_rect_contains(x, y, radius):
    cx = min(max(x, radius), 1.0 - radius)
    cy = min(max(y, radius), 1.0 - radius)
    return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 <= radius or (
        radius <= x <= 1.0 - radius or radius <= y <= 1.0 - radius
    )


def sample_color(x, y):
    """정규화 좌표 (0~1)에서의 색을 돌려준다. (r, g, b, a)"""
    if not _rounded_rect_contains(x, y, 0.22):
        return (0, 0, 0, 0)

    color = NAVY
    # 노란 원
    if ((x - 0.5) ** 2 + (y - 0.5) ** 2) ** 0.5 <= 0.355:
        color = ACCENT
        # 원 안의 W 글자
        distance = min(
            _segment_distance(x, y, W_POINTS[i][0], W_POINTS[i][1],
                              W_POINTS[i + 1][0], W_POINTS[i + 1][1])
            for i in range(len(W_POINTS) - 1)
        )
        if distance <= W_THICKNESS:
            color = NAVY
    return (color[0], color[1], color[2], 255)


def render(size):
    supersample = 4
    big = size * supersample
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            r_total = g_total = b_total = a_total = 0
            for sy in range(supersample):
                for sx in range(supersample):
                    px = (x * supersample + sx + 0.5) / big
                    py = (y * supersample + sy + 0.5) / big
                    r, g, b, a = sample_color(px, py)
                    r_total += r * a
                    g_total += g * a
                    b_total += b * a
                    a_total += a
            count = supersample * supersample
            if a_total == 0:
                row.append((0, 0, 0, 0))
            else:
                row.append((
                    round(r_total / a_total),
                    round(g_total / a_total),
                    round(b_total / a_total),
                    round(a_total / count),
                ))
        rows.append(row)
    return rows


def main():
    for folder, size in SIZES.items():
        path = os.path.join(RES, folder, 'ic_launcher.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_png(path, size, size, render(size))
        print('wrote', path)


if __name__ == '__main__':
    main()
