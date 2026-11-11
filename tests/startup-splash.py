"""Exercise the startup barrier and real QQuickWindow frames without Wayland."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-startup-") as directory:
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic",
               QT_QUICK_BACKEND=os.environ.get("QT_QUICK_BACKEND", "software"),
               QS_DISABLE_FILE_WATCHER="1")
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    for key, name in (("XDG_RUNTIME_DIR", "run"), ("XDG_CONFIG_HOME", "config"),
                      ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state"),
                      ("XDG_DATA_HOME", "data")):
        path = Path(directory) / name
        path.mkdir(mode=0o700)
        env[key] = str(path)
    settings = Path(env["XDG_CONFIG_HOME"]) / "nayori" / "settings.json"
    settings.parent.mkdir()
    settings.write_text(json.dumps({"version": 1, "unrelated": {"keep": 42},
                                    "startupSplashFadeDuration": 999, "startupSplashEnabled": "bad"}))
    cache = Path(env["XDG_CACHE_HOME"]) / "nayori" / "startup.json"
    cache.parent.mkdir()
    cache.write_text(json.dumps({"version": 1, "accent": "#679AC8"}))
    corrupt = Path(env["XDG_CACHE_HOME"]) / "nayori-corrupt"
    corrupt.mkdir()
    (corrupt / "startup.json").write_text("{broken")
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/StartupSplashSmoke.qml"),
                             "--no-color"], env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "STARTUP_SPLASH_PASS" in output, output
    assert not any(error in output for error in ("STARTUP_SPLASH_FAIL", "TypeError", "ReferenceError",
                                                "Unable to assign", "Binding loop", "Failed to load")), output
    assert json.loads(cache.read_text())["accent"] == "#E8AA70"
    saved = json.loads(settings.read_text())
    assert saved["unrelated"] == {"keep": 42}
    assert saved["startupSplashEnabled"] is False
    assert saved["startupSplashDynamicAccent"] is False
    assert saved["startupSplashFadeDuration"] == 0
print("STARTUP_SPLASH_TESTS_PASS")
