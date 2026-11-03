#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/quick-capture.py
node tests/quick-capture-routing.cjs
/usr/lib/qt6/bin/qmllint --missing-property disable --uncreatable-type disable -I /usr/lib/qt6/qml \
    services/quickcapture/*.qml surfaces/island/QuickCapture.qml tests/smoke/QuickCaptureSmoke.qml
runtime=$(mktemp -d /tmp/nayori-quick-capture.XXXXXX)
trap 'rm -rf "$runtime"' EXIT
mkdir -m 700 "$runtime/run" "$runtime/vault"
export XDG_RUNTIME_DIR="$runtime/run" XDG_STATE_HOME="$runtime/state" QS_DISABLE_FILE_WATCHER=1
export XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache" XDG_DATA_HOME="$runtime/data"
export NAYORI_TEST_VAULT="$runtime/vault"
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY DISPLAY NIRI_SOCKET
timeout 20s qs -p tests/smoke/QuickCaptureSmoke.qml --no-color > "$runtime/smoke.log" 2>&1 || { cat "$runtime/smoke.log"; exit 1; }
cat "$runtime/smoke.log"
rg -q QUICK_CAPTURE_SMOKE_PASS "$runtime/smoke.log"
! rg -q 'FAIL|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/smoke.log"
