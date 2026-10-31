"""Exercise independent visit persistence with real Quickshell in temporary paths."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-usage-") as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    def run(folder):
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/SettingsUsageSmoke.qml"), "--no-color"],
            env=dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
                     QS_DISABLE_FILE_WATCHER="1", XDG_RUNTIME_DIR=str(runtime), NAYORI_USAGE_DIR=str(folder)),
            capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "USAGE_PASS" in output and "USAGE_FAIL" not in output, output
        assert not any(token in output for token in ["ReferenceError", "TypeError", "Failed to load"]), output
    normal = base / "normal"
    run(normal)
    path = normal / "settings-usage.json"
    saved = json.loads(path.read_text())
    assert saved["counts"] == {"sound": 2, "display": 2, "integrations": 1}, saved
    saved["future"] = {"nested": True}
    path.write_text(json.dumps(saved))
    run(normal)
    saved = json.loads(path.read_text())
    assert saved["counts"] == {"sound": 4, "display": 4, "integrations": 2} and saved["future"] == {"nested": True}, saved
    for name, text in [("corrupt", "{broken"), ("unsupported", '{"version":99,"future":true}')]:
        folder = base / name
        folder.mkdir()
        target = folder / "settings-usage.json"
        target.write_text(text)
        run(folder)
        assert target.read_text() == text
print("PASS usage: first load, queued visits, counts, recency, restart, unknown fields, protected files")
