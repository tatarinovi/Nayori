"""Exercise the per-monitor controls and custom menu on an isolated offscreen shell."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="npm-") as directory:
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic",
               QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1",
               XDG_RUNTIME_DIR=directory, NAYORI_SETTINGS_DIR=directory + "/config")
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/PanelModesSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "PANEL_MODES_SMOKE_PASS" in output, output
    assert not any(marker in output for marker in ["FAIL", "ReferenceError", "TypeError", "Unable to assign", "Binding loop"]), output
    print("PASS per-monitor panel controls, keyboard menu, persistence and edge visibility")
