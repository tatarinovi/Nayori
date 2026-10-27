#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import struct, zlib
from pathlib import Path
root = Path("tests/fixtures/palette")
root.mkdir(parents=True, exist_ok=True)

def rgba(hex_color, alpha=255):
    text = hex_color.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), alpha)

def write_png(path, width, height, pixels):
    if len(pixels) != width * height:
        raise SystemExit(f"{path} has {len(pixels)} pixels, expected {width * height}")
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)

def blocks(spec):
    pixels = []
    for count, color in spec:
        pixels.extend([color] * count)
    return pixels

size = 32 * 32
dark = rgba("#121217")
lavender = rgba("#C4A8E0")
black = rgba("#000000")
near_black = rgba("#101014")
white = rgba("#FFFFFF")
gray = rgba("#808080")
red = rgba("#FF0000")
green = rgba("#00FF00")
blue = rgba("#0000FF")
clear_red = rgba("#FF0000", 0)

write_png(root / "lavender-dark.png", 32, 32, blocks([(768, dark), (256, lavender)]))
write_png(root / "black.png", 32, 32, blocks([(size, black)]))
write_png(root / "white.png", 32, 32, blocks([(size, white)]))
write_png(root / "gray.png", 32, 32, blocks([(size, gray)]))
write_png(root / "red.png", 32, 32, blocks([(size, red)]))
write_png(root / "green.png", 32, 32, blocks([(size, green)]))
write_png(root / "blue.png", 32, 32, blocks([(size, blue)]))
write_png(root / "competing.png", 32, 32, blocks([(512, near_black), (256, red), (256, lavender)]))
write_png(root / "transparent.png", 32, 32, blocks([(768, clear_red), (256, lavender)]))
write_png(root / "clear.png", 32, 32, blocks([(size, clear_red)]))
write_png(root / "RED.PNG", 32, 32, blocks([(size, red)]))
(root / "corrupt.png").write_bytes(b"not a png, really\n")
(root / "picture.bmp").write_bytes(b"not a bitmap\n")
(root / "broken.jpg").write_bytes(b"not a jpeg\n")
(root / "missing.png").unlink(missing_ok=True)
PY

# Flat colors only. Do not resize the bundled 3344px wallpaper.
magick -size 32x32 'xc:#FF0000' -strip -quality 100 tests/fixtures/palette/flat.jpg
magick -size 32x32 'xc:#5C8A86' -strip tests/fixtures/palette/flat.jpeg
magick -size 32x32 'xc:#C4A8E0' -strip tests/fixtures/palette/flat.webp

node tests/palette-pick.cjs

# Directory imports resolve through tests/smoke/services -> ../../services.
# Quickshell qmltypes mark some factory types uncreatable; the quantizer is creatable.
/usr/lib/qt6/bin/qmllint --uncreatable-type disable --missing-property disable -I /usr/lib/qt6/qml \
    services/palette/AccentExtractor.qml tests/smoke/AccentExtractorSmoke.qml

runtime=$(mktemp -d /tmp/nayori-accent-check.XXXXXX)
chmod 700 "$runtime"
export NAYORI_PALETTE_FIXTURES="$PWD/tests/fixtures/palette" XDG_RUNTIME_DIR="$runtime" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software QS_DISABLE_FILE_WATCHER=1
timeout 20s qs -p tests/smoke/AccentExtractorSmoke.qml --no-color > "$runtime/accent.log" 2>&1 || true
cat "$runtime/accent.log"
rg -q ACCENT_EXTRACTOR_PASS "$runtime/accent.log"
if rg -q 'ACCENT_EXTRACTOR_FAIL|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/accent.log"; then
    printf 'Accent extractor smoke failed\n' >&2
    exit 1
fi

files=(
    services/palette/AccentExtractor.qml
    services/palette/PalettePick.js
    tests/smoke/AccentExtractorSmoke.qml
    tests/palette-pick.cjs
    scripts/check-accent.sh
)
git diff --check -- "${files[@]}"
printf 'Accent checks passed. Test data: %s\n' "$runtime"
