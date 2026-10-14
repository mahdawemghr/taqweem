#!/usr/bin/env python3
"""Generates every platform icon + native launch image from the brand kit.

Source: brand/png/medallion_emerald.png (+ mark_gold.png for the monochrome
Android layer), rendered by the vector painter (see docs/design/brand-kit.md).
Run from the repo root:  python3 tool/gen_icons.py
"""
import os
from PIL import Image, ImageDraw

EMERALD = (8, 52, 44)          # #08342C  (BrandColors.emerald)
EMERALD_DEEP = (8, 38, 35)     # #082623
MED = Image.open('brand/png/medallion_emerald.png').convert('RGBA')
MARK = Image.open('brand/png/mark_gold.png').convert('RGBA')


def save(img, path, **kw):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, **kw)


def bg(size):
    """Deep emerald square with a soft lighter centre."""
    im = Image.new('RGB', (size, size), EMERALD_DEEP)
    glow = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse((size * .1, size * .1, size * .9, size * .9), fill=255)
    from PIL import ImageFilter
    glow = glow.filter(ImageFilter.GaussianBlur(size * .18))
    return Image.composite(Image.new('RGB', (size, size), EMERALD), im, glow)


def medallion(size, frac):
    m = int(size * frac)
    return MED.resize((m, m), Image.LANCZOS)


def icon(size, frac=0.86, opaque=True):
    base = bg(size).convert('RGBA')
    m = medallion(size, frac)
    base.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return base.convert('RGB') if opaque else base


def foreground(px, safe=0.62):
    """Android adaptive foreground: medallion inside the 66% safe zone."""
    im = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    m = medallion(px, safe)
    im.alpha_composite(m, ((px - m.width) // 2, (px - m.height) // 2))
    return im


def monochrome(px, safe=0.62):
    m = MARK.resize((int(px * safe),) * 2, Image.LANCZOS)
    a = m.split()[3]
    white = Image.new('RGBA', m.size, (255, 255, 255, 255))
    white.putalpha(a)
    im = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    im.alpha_composite(white, ((px - m.width) // 2, (px - m.height) // 2))
    return im


# ---- Android ---------------------------------------------------------------
res = 'android/app/src/main/res'
for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    legacy = icon(px, 0.86)
    save(legacy, f'{res}/mipmap-{name}/ic_launcher.png')
for name, px in {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}.items():
    save(foreground(px), f'{res}/drawable-{name}/ic_launcher_foreground.png')
    save(monochrome(px), f'{res}/drawable-{name}/ic_launcher_monochrome.png')
    save(medallion(int(px * 1.2), 1.0), f'{res}/drawable-{name}/launch_logo.png')
os.makedirs(f'{res}/mipmap-anydpi-v26', exist_ok=True)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
''')
open(f'{res}/values/colors.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#08342C</color>
    <color name="launch_background_color">#08342C</color>
</resources>
''')
launch_xml = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Native launch screen: flat emerald + centred medallion; the Flutter
     splash continues from the same pixels. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/launch_background_color"/>
    <item>
        <bitmap android:gravity="center" android:src="@drawable/launch_logo"/>
    </item>
</layer-list>
'''
for d in ('drawable', 'drawable-v21'):
    open(f'{res}/{d}/launch_background.xml', 'w').write(launch_xml)
os.makedirs(f'{res}/values-v31', exist_ok=True)
for n in ('values-v31', 'values-night-v31'):
    os.makedirs(f'{res}/{n}', exist_ok=True)
    open(f'{res}/{n}/styles.xml', 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/launch_background_color</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''')

# ---- iOS -------------------------------------------------------------------
ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for f in os.listdir(ios):
    if f.endswith('.png'):
        w, h = Image.open(f'{ios}/{f}').size
        save(icon(w, 0.84), f'{ios}/{f}')
li = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for f in os.listdir(li):
    if f.endswith('.png'):
        w, h = Image.open(f'{li}/{f}').size
        s = max(w, h)
        save(medallion(s, 1.0), f'{li}/{f}')
sb = 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
t = open(sb).read()
t = t.replace('<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
              '<color key="backgroundColor" red="0.0314" green="0.2039" blue="0.1725" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>')
t = t.replace('<image name="LaunchImage" width="168" height="185"/>', '<image name="LaunchImage" width="168" height="168"/>')
open(sb, 'w').write(t)

# ---- macOS -----------------------------------------------------------------
mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
for f in os.listdir(mac):
    if f.endswith('.png'):
        w, _ = Image.open(f'{mac}/{f}').size
        im = icon(w, 0.78, opaque=False)
        # macOS icons are rounded squares with transparent corners.
        mask = Image.new('L', (w, w), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, w - 1), radius=int(w * .2237), fill=255)
        im.putalpha(mask)
        save(im, f'{mac}/{f}')

# ---- Web -------------------------------------------------------------------
for n, s in ((192, 192), (512, 512)):
    save(icon(s, 0.86), f'web/icons/Icon-{n}.png')
    save(icon(s, 0.66), f'web/icons/Icon-maskable-{n}.png')   # maskable safe zone
save(icon(32, 0.9), 'web/favicon.png')

# ---- Windows / Linux -------------------------------------------------------
sizes = [16, 24, 32, 48, 64, 128, 256]
big = icon(256, 0.9, opaque=False)
big.save('windows/runner/resources/app_icon.ico', sizes=[(s, s) for s in sizes])
print('icons generated')
