#!/usr/bin/env python3
"""Exercise QML preview with real Xcursor bytes, no live session or user data."""
import os
from pathlib import Path
import struct
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-cursor-preview-") as tmp:
    base = Path(tmp)
    cursors = base / "data/icons/PreviewTest/cursors"
    cursors.mkdir(parents=True)
    kind = 0xfffd0002
    chunks, toc, offset = [], [], 40
    for size in (24, 48):
        chunk = struct.pack("<9I", 36, kind, size, 1, size, size, 0, 0, 0) + bytes([20, 40, 60, 255]) * size * size
        toc.append(struct.pack("<3I", kind, size, offset))
        chunks.append(chunk)
        offset += len(chunk)
    (cursors / "left_ptr").write_bytes(b"Xcur" + struct.pack("<3I", 16, 1, 2) + b"".join(toc + chunks))
    runtime = base / "run"
    runtime.mkdir(mode=0o700)
    env = {**os.environ, "HOME": tmp, "XDG_CONFIG_HOME": str(base / "config"),
           "XDG_DATA_HOME": str(base / "data"), "XDG_CACHE_HOME": str(base / "cache"),
           "XDG_STATE_HOME": str(base / "state"), "XDG_RUNTIME_DIR": str(runtime),
           "XCURSOR_THEME": "PreviewTest", "XDG_DATA_DIRS": str(base / "system"),
           "NIRI_CONFIG": str(base / "config/niri/config.kdl"),
           "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
           "QT_QPA_PLATFORMTHEME": "basic", "QS_DISABLE_FILE_WATCHER": "1"}
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/CursorPreviewSmoke.qml"), "--no-color"],
                            env=env, text=True, capture_output=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "CURSOR_PREVIEW_PASS" in output, output
    assert not any(marker in output for marker in ("Error:", "Unable to assign", "ReferenceError", "TypeError", "FAIL")), output
    assert not (base / "config").exists(), "Preview must not create settings"
    print("CURSOR_PREVIEW_PASS")
