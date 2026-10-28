"""Verify light palette contrast, reactive switching, and both material styles."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-theme-") as directory:
    env = dict(os.environ, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="offscreen",
               QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
               QS_DISABLE_FILE_WATCHER="1")
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/ColorSchemeSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "COLOR_SCHEME_PASS" in output, output
    assert not any(error in output for error in ["COLOR_SCHEME_FAIL", "TypeError", "ReferenceError",
                                                "Unable to assign", "Binding loop", "Failed to load"]), output
print("COLOR_SCHEME_TESTS_PASS")
