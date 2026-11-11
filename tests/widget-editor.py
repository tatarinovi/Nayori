"""CI regression coverage for the real editor, without a desktop session."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-widget-editor-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
               XDG_DATA_HOME=str(base / "data"), QT_QPA_PLATFORM="offscreen",
               QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1")
    for name in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(name, None)
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/WidgetEditorSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=20)
    log = result.stdout + result.stderr
    assert result.returncode == 0 and "WIDGET_EDITOR_PASS" in log, log
    assert not any(error in log for error in (
        "WIDGET_EDITOR_FAIL", "ReferenceError", "TypeError", "Unable to assign", "Binding loop",
        "Failed to load", "unavailable", "Cannot assign", "Error:"
    )), log
print("WIDGET_EDITOR_PASS: accordion geometry, selected settings, grid and alignment guides")
