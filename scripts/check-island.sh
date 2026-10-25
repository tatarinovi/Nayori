#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
node tests/island-controller.cjs
# Quickshell qmltypes omit dynamic model values and Loader item members.
/usr/lib/qt6/bin/qmllint --missing-property disable -I /usr/lib/qt6/qml \
    services/island/*.qml surfaces/island/*.qml \
    tests/smoke/IslandBehaviorSmoke.qml tests/smoke/AudioReactionSmoke.qml tests/smoke/NotificationBridgeSmoke.qml tests/smoke/IslandWheelSmoke.qml
runtime=$(mktemp -d /tmp/nayori-island-check.XXXXXX)
trap 'rm -rf "$runtime"' EXIT
chmod 700 "$runtime"
export QS_DISABLE_FILE_WATCHER=1 XDG_RUNTIME_DIR="$runtime" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software
NAYORI_ISLAND_AUTOTEST=1 timeout 10s qs -p tests/smoke/IslandBehaviorSmoke.qml --no-color > "$runtime/behavior.log" 2>&1
cat "$runtime/behavior.log"
rg -q ISLAND_BEHAVIOR_PASS "$runtime/behavior.log"
! rg -q 'Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/behavior.log"
timeout 12s qs -p tests/smoke/AudioReactionSmoke.qml --no-color > "$runtime/audio.log" 2>&1
cat "$runtime/audio.log"
rg -q AUDIO_REACTION_PASS "$runtime/audio.log"
! rg -q 'Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/audio.log"
timeout 10s qs -p tests/smoke/IslandWheelSmoke.qml --no-color > "$runtime/wheel.log" 2>&1
cat "$runtime/wheel.log"
rg -q ISLAND_WHEEL_PASS "$runtime/wheel.log"
! rg -q 'FAIL!|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/wheel.log"
dbus-run-session -- python3 tests/notification-host.py
dbus-run-session -- python3 tests/notifications-bridge.py
git diff --check
