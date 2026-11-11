#!/usr/bin/env bash
# Disposable offscreen monitor checks; never launch shell.qml or change host profiles.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/system-monitor.py
/usr/lib/qt6/bin/qmllint --missing-property disable --uncreatable-type disable \
    -I /usr/lib/qt6/qml services/system/SystemMonitor.qml services/system/CpuSampler.qml \
    surfaces/island/SystemPage.qml surfaces/island/SystemGraph.qml surfaces/island/SystemIcon.qml tests/smoke/SystemMonitorSmoke.qml
runtime=$(mktemp -d /tmp/nayori-monitor-check.XXXXXX)
trap 'rm -rf "$runtime"' EXIT
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software QS_DISABLE_FILE_WATCHER=1
unset WAYLAND_DISPLAY DISPLAY NIRI_SOCKET
export XDG_RUNTIME_DIR="$runtime/run" XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache" XDG_STATE_HOME="$runtime/state" XDG_DATA_HOME="$runtime/data"
mkdir -m 700 "$XDG_RUNTIME_DIR"
code=0
dbus-run-session -- timeout -k 2s 22s qs -p "$(pwd -P)/tests/smoke/SystemMonitorSmoke.qml" --no-color > "$runtime/monitor.log" 2>&1 || code=$?
cat "$runtime/monitor.log"
[[ "$code" == 0 ]]
rg -q 'SYSTEM_MONITOR_PASS' "$runtime/monitor.log"
if rg -q 'FAIL|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration|Binding loop|recursive rearrange' "$runtime/monitor.log"; then exit 1; fi
git diff --check
