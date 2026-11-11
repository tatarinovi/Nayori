"""Exercise the complete imported catalogue, shared adapters, and restart storage."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-imported-") as tmp:
    base = Path(tmp)
    runtime = base / "run"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic",
               QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1",
               XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
               XDG_DATA_HOME=str(base / "data"))
    for name in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(name, None)
    for restore in (False, True):
        env["NAYORI_IMPORTED_RESTORE"] = "1" if restore else "0"
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/ImportedWidgetsSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=30)
        log = result.stdout + result.stderr
        marker = "IMPORTED_WIDGETS_RESTORE_PASS" if restore else "IMPORTED_WIDGETS_PASS"
        assert result.returncode == 0 and marker in log, log
        assert not any(word in log for word in ("IMPORTED_WIDGETS_FAIL", "ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Failed to load", "Cannot open", "Cannot load font")), log
        print(log)
print("IMPORTED_WIDGETS_TESTS_PASS")
