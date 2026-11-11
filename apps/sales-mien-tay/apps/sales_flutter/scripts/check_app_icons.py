#!/usr/bin/env python3
"""Verify PWA and Android Field Work FB icons were generated at their proper sizes."""
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
expected = {
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/favicon.png': 48,
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
}
for filename, size in expected.items():
    data = (root / filename).read_bytes()
    assert data.startswith(b'\x89PNG\r\n\x1a\n'), f'Invalid PNG: {filename}'
    assert struct.unpack('>II', data[16:24]) == (size, size), f'Invalid icon dimensions: {filename}'
    assert len(data) > 256, f'Empty icon: {filename}'
print('PASS: FB PWA 192/512 + favicon + Android densities')
