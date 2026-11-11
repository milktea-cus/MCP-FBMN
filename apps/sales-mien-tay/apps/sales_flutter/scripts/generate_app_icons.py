#!/usr/bin/env python3
"""Generate Field Work's deterministic FB icon PNGs (Python standard library only).

Run after flutter create so regenerated Android and PWA templates cannot overwrite
the FB artwork. The only brand color is the canonical Futurebook #6D249E.
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _rounded(x: float, y: float) -> bool:
    if not (4 <= x <= 96 and 4 <= y <= 96):
        return False
    dx = max(24 - x, 0, x - 76)
    dy = max(24 - y, 0, y - 76)
    return dx * dx + dy * dy <= 20 * 20


def _ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1


def _letter(x: float, y: float) -> bool:
    f = ((20 <= x <= 28 and 29 <= y <= 74)
         or (20 <= x <= 46 and 29 <= y <= 37)
         or (20 <= x <= 42 and 47 <= y <= 55))
    spine = 53 <= x <= 61 and 29 <= y <= 74
    upper = (x >= 57 and _ellipse(x, y, 62.4, 41.1, 17.5, 12.2)
             and not _ellipse(x, y, 64.2, 41.1, 8.3, 4.9))
    lower = (x >= 57 and _ellipse(x, y, 62.4, 61.9, 18.2, 13.1)
             and not _ellipse(x, y, 64.3, 61.9, 8.8, 5.4))
    return f or spine or upper or lower


def _chunk(name: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(name + payload) & 0xffffffff
    return struct.pack('>I', len(payload)) + name + payload + struct.pack('>I', crc)


def make_png(size: int) -> bytes:
    pixels = bytearray()
    for py in range(size):
        pixels.append(0)  # PNG per-scanline filter: none
        for px in range(size):
            alpha = 0
            white = 0
            for sy in range(2):
                y = (py + (sy + .5) / 2) * 100 / size
                for sx in range(2):
                    x = (px + (sx + .5) / 2) * 100 / size
                    if _rounded(x, y):
                        alpha += 1
                        if _letter(x, y):
                            white += 1
            if alpha == 0:
                pixels.extend((0, 0, 0, 0))
            else:
                ratio = white / alpha
                pixels.extend((int(109 + 146 * ratio), int(36 + 219 * ratio),
                               int(158 + 97 * ratio), alpha * 255 // 4))
    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n' + _chunk(b'IHDR', header)
            + _chunk(b'IDAT', zlib.compress(pixels, 9)) + _chunk(b'IEND', b''))


def generate(root: Path = ROOT) -> list[Path]:
    assets = [
        (192, 'web/icons/Icon-192.png'),
        (512, 'web/icons/Icon-512.png'),
        (48, 'web/favicon.png'),
        (48, 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'),
        (72, 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'),
        (96, 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'),
        (144, 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'),
        (192, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'),
    ]
    generated = []
    cache = {}
    for size, filename in assets:
        path = root / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        if size not in cache:
            cache[size] = make_png(size)
        path.write_bytes(cache[size])
        generated.append(path)
    return generated


if __name__ == '__main__':
    for destination in generate():
        print('Generated FB icon:', destination)
