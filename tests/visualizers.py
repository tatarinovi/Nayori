"""Isolated multi-instance renderer/editor and settings restart regression."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-visualizers-") as tmp:
    base = Path(tmp)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    config = base / "config"
    config.mkdir()
    (config / "settings.json").write_text(json.dumps({"version": 1, "unrelated": {"preserve": True}}))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), NAYORI_VISUALIZER_TEST_DIR=str(config),
               QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
               QS_DISABLE_FILE_WATCHER="1")
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    for restore in (False, True):
        env["NAYORI_VISUALIZER_RESTORE"] = "1" if restore else "0"
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/VisualizerSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=25)
        log = result.stdout + result.stderr
        marker = "VISUALIZER_RESTORE_PASS" if restore else "VISUALIZER_SMOKE_PASS"
        assert result.returncode == 0 and marker in log, log
        assert not any(x in log for x in ("ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Failed to load", "VISUALIZER_FAIL")), log
    result = subprocess.run(["qs", "-p", str(root / "tests/smoke/VisualizerAudioSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=15)
    log = result.stdout + result.stderr
    assert result.returncode == 0 and "VISUALIZER_AUDIO_PASS" in log, log
    assert not any(x in log for x in ("ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Failed to load", "VISUALIZER_AUDIO_FAIL")), log
    data = json.loads((config / "settings.json").read_text())
    assert data["unrelated"] == {"preserve": True}
    assert len(data["desktopVisualizers"]["items"]) == 13
print("VISUALIZER_SETTINGS_PASS: styles, field, audio, monitors, motion, persistence")
