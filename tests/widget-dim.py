"""Check the focused NowPlaying copy and, on a graphics backend, its pixels."""
import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-widget-dim-") as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
               QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", NAYORI_WIDGET_DIM_DIR=str(base),
               QS_DISABLE_FILE_WATCHER="1")
    env.setdefault("QT_QUICK_BACKEND", "software")
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    result = subprocess.run(["qs", "-p", str(ROOT / "tests/smoke/WidgetDimSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "WIDGET_DIM_PASS" in output, output
    before = Image.open(base / "before.png").convert("RGBA")
    after = Image.open(base / "after.png").convert("RGBA")
    assert before.size == after.size
    if env.get("QT_QUICK_BACKEND") == "rhi":
        samples = [(before.getpixel((x, y)), after.getpixel((x, y)))
                   for y in range(before.height) for x in range(before.width)
                   if before.getpixel((x, y))[3] > 240 and max(before.getpixel((x, y))[:3]) > 60]
        assert len(samples) > 100, "no visible NowPlaying pixels"
        for a, b in samples:
            assert abs(a[3] - b[3]) <= 2, ("dim changed alpha", a, b)
            assert all(abs(b[i] - a[i] * 0.5) <= 3 for i in range(3)), (a, b)
        print("WIDGET_DIM_PIXELS_PASS")
    else:
        print("WIDGET_DIM_PASS (software: focus/layer behavior; shader pixels require graphics backend)")
