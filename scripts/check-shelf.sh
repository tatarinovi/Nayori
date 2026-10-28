#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/shelf-store.py
node tests/shelf-drop.cjs
/usr/lib/qt6/bin/qmllint --missing-property disable --uncreatable-type disable -I /usr/lib/qt6/qml \
    services/shelf/*.qml surfaces/island/ShelfPage.qml services/clipboard/ClipboardService.qml tests/smoke/ShelfSmoke.qml tests/smoke/ShelfClipboardSmoke.qml
runtime=$(mktemp -d /tmp/nayori-shelf-check.XXXXXX)
trap 'rm -rf "$runtime"' EXIT
mkdir -m 700 "$runtime/run"
export XDG_RUNTIME_DIR="$runtime/run" XDG_STATE_HOME="$runtime/state" QS_DISABLE_FILE_WATCHER=1
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY DISPLAY NIRI_SOCKET
timeout 15s qs -p tests/smoke/ShelfSmoke.qml --no-color > "$runtime/shelf.log" 2>&1 || { cat "$runtime/shelf.log"; exit 1; }
cat "$runtime/shelf.log"
rg -q SHELF_SMOKE_PASS "$runtime/shelf.log"
! rg -q 'FAIL|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/shelf.log"
# Check both real QML bridges together with deterministic external commands.
mkdir "$runtime/bin"
cat > "$runtime/bin/wl-paste" <<'FAKE'
#!/bin/sh
case "$1" in
    --list-types) printf 'text/plain;charset=utf-8\n' ;;
    *) printf 'Текст из текущего буфера' ;;
esac
FAKE
cat > "$runtime/bin/wl-copy" <<'FAKE'
#!/bin/sh
cat > /dev/null
FAKE
chmod +x "$runtime/bin/wl-paste" "$runtime/bin/wl-copy"
export PATH="$runtime/bin:$PATH" XDG_STATE_HOME="$runtime/clipboard-state"
timeout 15s qs -p tests/smoke/ShelfClipboardSmoke.qml --no-color > "$runtime/clipboard.log" 2>&1 || { cat "$runtime/clipboard.log"; exit 1; }
cat "$runtime/clipboard.log"
rg -q SHELF_CLIPBOARD_PASS "$runtime/clipboard.log"
! rg -q 'FAIL|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/clipboard.log"
