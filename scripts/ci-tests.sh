#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
    unit)
        for test in tests/*.cjs; do
            printf '\n>>> %s\n' "$test"
            node "$test"
        done
        for test in island-audio lyrics-fetch super-tap clipboard-store capture naomi-layers overview-backdrop launcher-focus; do
            printf '\n>>> %s\n' "$test"
            python3 "tests/$test.py"
        done
        ;;
    smoke)
        # These tests use disposable data and offscreen Qt, never the live desktop.
        export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic
        export QT_QUICK_BACKEND=software QS_DISABLE_FILE_WATCHER=1
        unset WAYLAND_DISPLAY DISPLAY NIRI_SOCKET
        runtime=$(mktemp -d /tmp/nayori-ci.XXXXXX)
        trap 'rm -rf "$runtime"' EXIT
        export XDG_RUNTIME_DIR="$runtime/run" XDG_CONFIG_HOME="$runtime/config"
        export XDG_CACHE_HOME="$runtime/cache" XDG_STATE_HOME="$runtime/state"
        export XDG_DATA_HOME="$runtime/data"
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        for suite in island music canvas accent; do
            printf '\n>>> %s\n' "$suite"
            bash "scripts/check-$suite.sh"
        done
        for test in settings weather-service settings-window settings-usage naomi-sprite wallpaper-library lockscreen; do
            printf '\n>>> %s\n' "$test"
            python3 "tests/$test.py"
        done
        for fixture in Clipboard NaomiPixel; do
            log="$runtime/$fixture.log"
            timeout 20s qs -p "tests/smoke/${fixture}Smoke.qml" --no-color > "$log" 2>&1 || { cat "$log"; exit 1; }
            cat "$log"
            case "$fixture" in
                Clipboard) marker=CLIPBOARD_SMOKE_PASS ;;
                NaomiPixel) marker=NAOMI_PIXEL_PASS ;;
            esac
            rg -q "$marker" "$log"
            ! rg -q 'FAIL|Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$log"
        done
        ;;
    *)
        printf 'Usage: bash scripts/ci-tests.sh {unit|smoke}\n' >&2
        exit 2
        ;;
esac
