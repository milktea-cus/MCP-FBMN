#!/usr/bin/env python3
"""Fail the build if any platform icon is stale/default or out of safe area."""
import json
import math
import struct
import xml.etree.ElementTree as ET
from generate_app_icons import ROOT,VERSION,POLYGONS,assets,png,xml_assets
cache={}
for filename,spec in assets().items():
    path=ROOT/filename
    data=path.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n', filename
    assert struct.unpack('>II',data[16:24])==(spec[0],spec[0]), filename
    if spec not in cache:cache[spec]=png(*spec)
    assert data==cache[spec],f'Unexpected icon artwork: {filename}'
for filename,expected in xml_assets().items():
    path=ROOT/filename
    assert path.read_text(encoding='utf8')==expected,filename
    ET.fromstring(expected)
for scale,limit in ((.90,40),(.78,100*33/108)):
    assert max(math.hypot(x-50,y-50)*scale for poly in POLYGONS for x,y in poly)<limit
manifest=json.loads((ROOT/'web/manifest.json').read_text())
assert manifest['name']=='Field Work' and manifest['start_url']=='.'
for size in (192,512):
    for purpose,part in [('any',''),('maskable','-maskable')]:
        assert any(i['src']==f'icons/{VERSION}{part}-{size}.png' and i['sizes']==f'{size}x{size}' and i['purpose']==purpose for i in manifest['icons'])
index=ROOT/'web/index.html'
if index.exists():
    html=index.read_text()
    assert f'icons/{VERSION}-apple.png' in html and f'{VERSION}-favicon.png' in html and '<title>Field Work</title>' in html
android=(ROOT/'android/app/src/main/AndroidManifest.xml').read_text()
assert 'android:icon="@mipmap/ic_launcher"' in android and 'android:roundIcon="@mipmap/ic_launcher_round"' in android
print('PASS: exact approved artwork, safe zones, PWA/iOS/favicon and Android adaptive/monochrome icons')
