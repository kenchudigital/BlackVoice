#!/usr/bin/env bash
# 從 res/ 原始檔生成 Xcode Assets.xcassets icon
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 << PY
from PIL import Image
from pathlib import Path

root = Path("$ROOT")
app_src = root / "res/logo_app.png"
header_src = root / "res/logo_header_icon_removed_background.png"

NAVY = (26, 41, 65)

def subject_bbox(img: Image.Image):
    w, h = img.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if a < 128:
                continue
            is_navy = r < 60 and g < 70 and b < 90 and (r + g + b) < 120
            if not is_navy:
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
    return (minx, miny, maxx, maxy) if maxx >= minx else (0, 0, w - 1, h - 1)

def prepare_app_icon(src: Path, size: int) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    minx, miny, maxx, maxy = subject_bbox(img)
    cropped = img.crop((minx, miny, maxx + 1, maxy + 1))

    # 做咩：主體放大填滿 canvas，深藍底不透明（避免 Dock 灰邊）。
    fill_ratio = 0.88
    content = int(size * fill_ratio)
    cw, ch = cropped.size
    scale = min(content / cw, content / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    scaled = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGB", (size, size), NAVY)
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas

def generate_app_icons(src: Path, iconset: Path):
    specs = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    iconset.mkdir(parents=True, exist_ok=True)
    for size, fname in specs:
        prepare_app_icon(src, size).save(iconset / fname)

def white_to_black_template(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a > 16 and (r + g + b) > 200:
                out.putpixel((x, y), (0, 0, 0, min(255, a)))
    bbox = out.getbbox()
    return out.crop(bbox) if bbox else out

def generate_menu_bar_icons(src: Path, out_dir: Path, res_copy: Path):
    cropped = white_to_black_template(src)
    side = max(cropped.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cropped.width) // 2
    oy = (side - cropped.height) // 2
    square.paste(cropped, (ox, oy), cropped)
    out_dir.mkdir(parents=True, exist_ok=True)
    for canvas_size, filename, pad in [(18, "menubar.png", 1), (36, "menubar@2x.png", 2)]:
        content = canvas_size - pad * 2
        scaled = square.resize((content, content), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        canvas.paste(scaled, (pad, pad), scaled)
        canvas.save(out_dir / filename)
    square.resize((36, 36), Image.Resampling.LANCZOS).save(res_copy)

generate_app_icons(app_src, root / "apps/macos/BlackVoice/BlackVoice/Assets.xcassets/AppIcon.appiconset")
generate_app_icons(app_src, root / "apps/macos/BlackVoice/BlackVoiceWidget/Assets.xcassets/AppIcon.appiconset")
generate_menu_bar_icons(
    header_src,
    root / "apps/macos/BlackVoice/BlackVoice/Assets.xcassets/MenuBarIcon.imageset",
    root / "res/menu_bar_icon.png",
)
print("Icons generated (app icon: opaque navy, subject scaled to 88%)")
PY
