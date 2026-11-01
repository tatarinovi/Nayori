"""Test launcher history in isolated state directories."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-launcher-usage-") as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)

    data = base / "data"
    applications = data / "applications"
    applications.mkdir(parents=True)
    for ident, name in (("alpha", "Example Alpha"), ("beta", "Example Beta")):
        (applications / f"{ident}.desktop").write_text(
            f"[Desktop Entry]\nType=Application\nName={name}\nExec=true\n")

    def run(folder):
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic",
                   QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1",
                   XDG_RUNTIME_DIR=str(runtime), XDG_DATA_HOME=str(data), NAYORI_USAGE_DIR=str(folder))
        for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
            env.pop(key, None)
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/LauncherUsageSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "LAUNCHER_USAGE_PASS" in output, output
        assert not any(token in output for token in ("ReferenceError", "TypeError", "Failed to load")), output

    normal = base / "normal"
    run(normal)
    path = normal / "launcher-usage.json"
    saved = json.loads(path.read_text())
    assert saved["counts"] == {"alpha.desktop": 2, "beta.desktop": 2}, saved
    saved["future"] = True
    path.write_text(json.dumps(saved))
    run(normal)
    saved = json.loads(path.read_text())
    assert saved["counts"] == {"alpha.desktop": 4, "beta.desktop": 4} and saved["future"], saved
    for name, content in (("corrupt", "{broken"), ("unsupported", '{"version":99}')):
        folder = base / name
        folder.mkdir()
        target = folder / "launcher-usage.json"
        target.write_text(content)
        run(folder)
        assert target.read_text() == content
print("PASS launcher usage: persistence, frequency, recency, missing entries and protected files")
