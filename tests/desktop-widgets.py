"""Check widget configuration, independent monitors and restart persistence."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-widgets-") as tmp:
    base = Path(tmp)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    settings = base / "settings"
    settings.mkdir()
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), NAYORI_WIDGETS_TEST_DIR=str(settings),
               QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
               QS_DISABLE_FILE_WATCHER="1")
    env.pop("WAYLAND_DISPLAY", None)
    for restore in (False, True):
        env["NAYORI_WIDGETS_RESTORE"] = "1" if restore else "0"
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/DesktopWidgetsSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=15)
        log = result.stdout + result.stderr
        marker = "DESKTOP_WIDGET_RESTORE_PASS" if restore else "DESKTOP_WIDGET_PASS"
        assert result.returncode == 0 and marker in log, log
        assert not any(x in log for x in ("DESKTOP_WIDGET_FAIL", "ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Failed to load")), log
    data = json.loads((settings / "settings.json").read_text())["desktopWidgets"]
    assert data["DP-1"]["items"][1]["text"] == "Пример заметки"
    assert data["HDMI-1"]["snap"] is False
print("DESKTOP_WIDGET_SETTINGS_PASS: layouts, notes, per-screen storage and restart")
