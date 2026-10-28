"""Regenerate ProjectBridge launcher assets on macOS without extra packages.
Run from the project root: python3 tool/generate_app_icons.py
"""
import json
from pathlib import Path
import struct
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix='projectbridge-icons-') as temporary:
    executable = str(Path(temporary) / 'render')
    subprocess.run(['clang', 'tool/generate_app_icon.c', '-framework', 'ApplicationServices', '-framework', 'ImageIO', '-o', executable], check=True)
    def icon(path, size):
        subprocess.run([executable, str(path), str(size)], check=True)
    icon('assets/branding/projectbridge-icon.png', 1024)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        icon(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
    for platform in ['ios', 'macos']:
        folder = Path(f'{platform}/Runner/Assets.xcassets/AppIcon.appiconset')
        for item in json.loads((folder / 'Contents.json').read_text())['images']:
            if 'filename' in item:
                size = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
                icon(folder / item['filename'], size)
    for size in [192, 512]:
        icon(f'web/icons/Icon-{size}.png', size)
        icon(f'web/icons/Icon-maskable-{size}.png', size)
    icon('web/favicon.png', 32)
    entries, images = [], []
    offset = 6 + 16 * 6
    for size in [16, 32, 48, 64, 128, 256]:
        path = Path(temporary) / f'{size}.png'
        icon(path, size)
        data = path.read_bytes()
        entries.append(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset))
        images.append(data)
        offset += len(data)
    Path('windows/runner/resources/app_icon.ico').write_bytes(struct.pack('<HHH', 0, 1, len(entries)) + b''.join(entries) + b''.join(images))
print('Generated ProjectBridge launcher icons for Android, iOS, macOS, Windows and web.')
