#!/usr/bin/env python3
"""Reproduce the Owner-approved location/check mark on every target.
Contours traced from approved artwork; solid FBMN purple avoids raster noise.
No external packages, fonts, network, or platform-dependent renderers.
"""
from __future__ import annotations
import hashlib
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PURPLE = (109, 36, 158)
VERSION = 'fieldwork-v19'
# Outer marker, circular cutout and tick. One source for all formats.
CONTOURS = (
 '49.20,14.91;43.78,15.63;40.27,16.67;37.80,17.70;33.73,20.10;31.26,22.09;29.19,24.16;26.32,27.99;23.68,33.25;22.25,38.28;21.77,43.14;22.25,47.77;23.37,51.75;25.28,56.06;28.39,61.16;34.13,68.74;47.53,84.85;49.04,85.96;50.40,86.04;51.12,85.81;52.23,84.85;64.43,70.10;69.86,63.16;72.89,58.69;75.28,54.23;76.95,49.60;77.67,45.85;77.75,41.39;77.35,38.12;76.79,35.73;74.96,30.86;72.01,26.00;68.26,21.93;65.87,20.02;63.64,18.58;59.33,16.59;54.07,15.23',
 '48.33,24.40;51.59,24.40;55.74,25.28;59.49,27.03;62.84,29.59;65.15,32.22;67.15,35.65;68.34,39.23;68.82,42.90;68.66,45.93;67.70,49.84;66.03,53.43;63.88,56.46;60.93,59.33;57.74,61.40;54.31,62.76;50.88,63.32;47.29,63.16;43.86,62.28;40.59,60.69;37.80,58.61;36.20,57.02;34.45,54.78;32.62,51.44;31.42,47.85;30.94,44.18;31.26,40.43;32.30,36.76;33.89,33.57;35.96,30.78;38.68,28.23;41.39,26.48;44.42,25.20',
 '62.20,35.81;61.32,34.69;60.21,34.13;59.01,34.05;57.74,34.53;46.73,45.93;42.42,41.87;41.39,41.31;40.51,41.15;39.23,41.39;37.96,42.34;37.32,43.94;37.56,45.45;37.96,46.17;44.66,52.95;46.17,53.67;47.77,53.51;49.36,52.31;61.56,39.31;62.20,38.36;62.44,37.48',
)
POLYGONS = tuple(tuple(tuple(map(float,p.split(','))) for p in s.split(';')) for s in CONTOURS)
PATH = ' '.join('M' + s.replace(';', ' L') + ' Z' for s in CONTOURS)

def chunk(name, payload):
    return struct.pack('>I',len(payload))+name+payload+struct.pack('>I',zlib.crc32(name+payload)&0xffffffff)

def png(size, mode='opaque', scale=1.0):
    """Supersampled even-odd scanline raster, with no white outer corners."""
    ss=4
    side=size*ss
    polygons=tuple(tuple((50+(x-50)*scale,50+(y-50)*scale) for x,y in poly) for poly in POLYGONS)
    counts=bytearray(size*size)
    opaque=bytearray(size*size)
    for sy in range(side):
        y=(sy+.5)*100/side
        edges=[]
        for poly in polygons:
            for (x1,y1),(x2,y2) in zip(poly,poly[1:]+poly[:1]):
                if (y1<=y<y2) or (y2<=y<y1):
                    edges.append(x1+(y-y1)*(x2-x1)/(y2-y1))
        edges.sort()
        for lo,hi in zip(edges[::2],edges[1::2]):
            for sx in range(max(0,int(lo*side/100+.5)), min(side,int(hi*side/100+.5))):
                counts[(sy//ss)*size+sx//ss]+=1
        if mode=='rounded':
            for sx in range(side):
                x=(sx+.5)*100/side
                dx=max(22-x,0,x-78);dy=max(22-y,0,y-78)
                if dx*dx+dy*dy<=22*22:
                    opaque[(sy//ss)*size+sx//ss]+=1
    data=bytearray()
    for y in range(size):
        data.append(0)
        for x in range(size):
            i=y*size+x; n=counts[i]
            if mode=='mark':
                data.extend((255,255,255,round(255*n/16)))
            else:
                rgb=tuple(round(c+(255-c)*n/16) for c in PURPLE)
                data.extend((*rgb,round(255*opaque[i]/16) if mode=='rounded' else 255))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(data,9))+chunk(b'IEND',b'')

def assets():
    specs={}
    for size in (192,512):
        specs[f'web/icons/Icon-{size}.png']=(size,'opaque',1.0)
        specs[f'web/icons/Icon-maskable-{size}.png']=(size,'opaque',.90)
        specs[f'web/icons/{VERSION}-{size}.png']=(size,'opaque',1.0)
        specs[f'web/icons/{VERSION}-maskable-{size}.png']=(size,'opaque',.90)
    specs['web/icons/apple-touch-icon.png']=(180,'opaque',1.0)
    specs[f'web/icons/{VERSION}-apple.png']=(180,'opaque',1.0)
    specs['web/favicon.png']=(48,'rounded',1.0)
    specs[f'web/{VERSION}-favicon.png']=(48,'rounded',1.0)
    for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        for name in ('ic_launcher','ic_launcher_round'):
            specs[f'android/app/src/main/res/mipmap-{density}/{name}.png']=(size,'rounded',1.0)
    return specs

def vector():
    return ('<vector xmlns:android="http://schemas.android.com/apk/res/android" '
            'android:width="108dp" android:height="108dp" android:viewportWidth="100" android:viewportHeight="100">\n'
            '    <group android:pivotX="50" android:pivotY="50" android:scaleX="0.78" android:scaleY="0.78">\n'
            f'        <path android:fillColor="#FFFFFF" android:fillType="evenOdd" android:pathData="{PATH}"/>\n'
            '    </group>\n</vector>\n')

def adaptive(monochrome=False):
    extra='    <monochrome android:drawable="@drawable/fieldwork_launcher_foreground"/>\n' if monochrome else ''
    return ('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/fieldwork_launcher_background"/>\n'
            '    <foreground android:drawable="@drawable/fieldwork_launcher_foreground"/>\n'+extra+'</adaptive-icon>\n')

def xml_assets():
    p='android/app/src/main/res/'
    files={p+'drawable/fieldwork_launcher_foreground.xml':vector(),
           p+'values/fieldwork_launcher_colors.xml':'<resources><color name="fieldwork_launcher_background">#6D249E</color></resources>\n'}
    for q in ('v26','v33'):
        for name in ('ic_launcher','ic_launcher_round'):
            files[p+f'mipmap-anydpi-{q}/{name}.xml']=adaptive(q=='v33')
    return files

def brand_web_index(root):
    path=root/'web/index.html'
    if not path.exists():
        return
    text=path.read_text(encoding='utf8')
    text=re.sub(r'(<meta\s+name="apple-mobile-web-app-title"\s+content=")[^"]*(")',r'\g<1>Field Work\2',text)
    text=re.sub(r'(<meta\s+name="description"\s+content=")[^"]*(")',r'\g<1>Khảo sát điểm bán và lập kế hoạch kinh doanh\2',text)
    text=re.sub(r'<title>.*?</title>','<title>Field Work</title>',text,flags=re.S)
    text=re.sub(r'(<link\s+rel="apple-touch-icon"\s+href=")[^"]*(")',rf'\g<1>icons/{VERSION}-apple.png\2',text)
    text=re.sub(r'(<link\s+rel="icon"\s+type="image/png"\s+href=")[^"]*(")',rf'\g<1>{VERSION}-favicon.png\2',text)
    path.write_text(text,encoding='utf8')

def generate(root=ROOT):
    cache={}; paths=[]
    for name,spec in assets().items():
        path=root/name;path.parent.mkdir(parents=True,exist_ok=True)
        if spec not in cache: cache[spec]=png(*spec)
        path.write_bytes(cache[spec]);paths.append(path)
    for name,content in xml_assets().items():
        path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(content,encoding='utf8');paths.append(path)
    brand_web_index(root)
    return paths

if __name__=='__main__':
    for destination in generate():
        print('Generated Field Work icon:',destination)
