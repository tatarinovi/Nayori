"""Compile the real root on the installed Wayland backend without creating its surfaces."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-root-") as runtime:
    display = os.environ["WAYLAND_DISPLAY"]
    if not display.startswith("/"):
        display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    env = dict(os.environ, XDG_RUNTIME_DIR=runtime, WAYLAND_DISPLAY=display,
               QT_QPA_PLATFORM="wayland", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software")
    result = subprocess.run(["qs", "-p", str(root / "RootConfigSmoke.qml"), "--no-color"],
                            env=env, text=True, capture_output=True, timeout=10)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "ROOT_CONFIG_PASS" in output, output
    assert not any(error in output for error in ["ROOT_CONFIG_FAIL", "TypeError", "ReferenceError", "Failed to load"]), output
print("ROOT_CONFIG_TESTS_PASS")
