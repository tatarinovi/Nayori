#!/usr/bin/env python3
"""Read a disposable niri configuration without contacting the real session."""
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="niri-primary-") as directory:
    tmp = Path(directory)
    runtime = tmp / "runtime"
    runtime.mkdir(mode=0o700)
    config = tmp / "config.kdl"
    content = 'output "DP-1" {\n    focus-at-startup\n}\noutput "DP-2" {\n}\n'
    config.write_text(content, encoding="utf-8")
    env = os.environ.copy()
    env.update({"HOME": directory, "NIRI_CONFIG": str(config), "XDG_RUNTIME_DIR": str(runtime),
                "XDG_CONFIG_HOME": str(tmp / "config"), "XDG_STATE_HOME": str(tmp / "state"),
                "XDG_CACHE_HOME": str(tmp / "cache"), "XDG_DATA_HOME": str(tmp / "data"),
                "QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "basic",
                "QT_QUICK_BACKEND": "software", "QS_DISABLE_FILE_WATCHER": "1"})
    for key in ("NIRI_SOCKET", "WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS"):
        env.pop(key, None)
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/NiriPrimarySmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=20, check=False)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "NIRI_PRIMARY_PASS" in output and "NIRI_PRIMARY_FAIL" not in output
    assert config.read_text(encoding="utf-8") == content
