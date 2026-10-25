#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# ImageMagick creates fixtures only; Canvas has no dependency on it.
magick assets/wallpapers/nayori.png /tmp/nayori-canvas-test.jpg
magick assets/wallpapers/nayori.png /tmp/nayori-canvas-test.webp
test_dir=$(mktemp -d /tmp/nayori-canvas-check.XXXXXX)
mkdir -p "$test_dir/runtime"
chmod 700 "$test_dir/runtime"
/usr/lib/qt6/bin/qmllint --uncreatable-type disable --missing-property disable -I /usr/lib/qt6/qml services/canvas/*.qml surfaces/canvas/*.qml surfaces/settings/WallpaperPage.qml
NAYORI_CANVAS_TEST_DIR="$test_dir/config" XDG_RUNTIME_DIR="$test_dir/runtime" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic \
    timeout 15s qs -p tests/smoke/CanvasSmoke.qml --no-color > "$test_dir/result.log" 2>&1
cat "$test_dir/result.log"
rg -q CANVAS_SMOKE_PASS "$test_dir/result.log"
! rg -q CANVAS_SMOKE_FAIL "$test_dir/result.log"
printf 'Canvas checks passed. Test data: %s\n' "$test_dir"
