#!/usr/bin/env python3
"""Inspect the actual APK, not just files before Gradle resource compilation."""
import glob
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

apk=Path(sys.argv[1])
tool=sorted(glob.glob(os.environ['ANDROID_HOME']+'/build-tools/*/aapt'))[-1]
resources=subprocess.check_output([tool,'dump','resources',str(apk)],text=True)
for name in ('mipmap/ic_launcher','mipmap/ic_launcher_round','drawable/fieldwork_launcher_foreground','color/fieldwork_launcher_background'):
    assert name in resources, f'Missing compiled resource {name}'
manifest=subprocess.check_output([tool,'dump','xmltree',str(apk),'AndroidManifest.xml'],text=True)
assert 'android:icon(' in manifest and 'android:roundIcon(' in manifest
with zipfile.ZipFile(apk) as z:
    assert z.testzip() is None
print('PASS: APK compiled resources include adaptive Field Work icon and round icon')
