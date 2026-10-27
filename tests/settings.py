"""Run real Quickshell persistence and page smoke checks in disposable directories."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="ns-") as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    def run(name, folder):
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
                   QS_DISABLE_FILE_WATCHER="1",
                   QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software",
                   NAYORI_SETTINGS_SCENARIO=name, NAYORI_SETTINGS_DIR=str(folder))
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/SettingsSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=20 if name == "ui" else 10)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and f"SETTINGS_PASS {name}" in output, output
        assert not any(s in output for s in ["ReferenceError", "TypeError", "Unable to assign", "Failed to load", "Binding loop", "SETTINGS_FAIL"]), output
        print(f"PASS {name}")
    storage = base / "normal"
    run("write", storage)
    path = storage / "settings.json"
    saved = json.loads(path.read_text())
    assert saved["weatherCity"] == "Москва" and saved["autoHideApps"]
    assert saved["weatherRefreshMinutes"] == 30
    assert saved["companionStyle"] == "layered"
    assert saved["companionEnabled"] is True
    assert saved["companionDesktopOnly"] is True
    assert saved["companionReactToPointer"] is False
    assert saved["companionSystemLines"] is False
    assert saved["companionScreen"] == "secondary"
    assert saved["companionSide"] == "left"
    assert saved["surfaceStyle"] == "frosted"
    assert saved["startIconStyle"] == "fox"
    before = path.read_bytes()
    run("restore", storage)
    assert path.read_bytes() == before
    run("revert", storage)
    assert path.read_bytes() == before
    saved.update(extra={"nested": [1, {"future": True}]})
    saved["weatherCity"] = "before"
    path.write_text(json.dumps(saved))
    run("write", storage)
    assert json.loads(path.read_text())["extra"] == saved["extra"]
    run("ui", storage)
    run("motion", base / "motion")
    mixed = base / "mixed"
    mixed.mkdir()
    (mixed / "settings.json").write_text(json.dumps({"version": 1, "topReserved": 5,
        "bottomReserved": "wrong", "autoHideTop": 1, "weatherCity": [],
        "extra": {"nested": {"keep": [1, 2]}}}))
    run("normalize", mixed)
    assert json.loads((mixed / "settings.json").read_text())["extra"] == {"nested": {"keep": [1, 2]}}
    run("flush", base / "flush")
    run("shutdown", base / "shutdown")
    assert json.loads((base / "shutdown/settings.json").read_text())["weatherCity"] == "Москва"
    for name, content in [("unsupported", '{"version":99,"future":{"x":1}}'),
                          ("recover", '{broken\n\x00'), ("backup-fail", '{broken')]:
        folder = base / name
        folder.mkdir()
        target = folder / "settings.json"
        target.write_text(content)
        if name == "backup-fail":
            # /proc is readable but cannot host a backup. Non-JSON input stays protected.
            target.unlink()
            target.symlink_to("/proc/version")
            folder.chmod(0o500)
        run(name, folder)
        if name == "recover":
            copies = list(folder.glob("settings.json.backup-*"))
            assert len(copies) == 1 and copies[0].read_bytes() == content.encode()
            assert json.loads(target.read_text())["weatherCity"] == "Recovered"
        elif name == "unsupported":
            assert target.read_text() == content
        else:
            assert target.is_symlink()
            folder.chmod(0o700)
    folder = base / "save-fail"
    folder.mkdir()
    # A directory at the target path cannot be atomically replaced by a JSON file.
    (folder / "settings.json").mkdir()
    run("unreadable", folder)
    folder = base / "readonly"
    folder.mkdir(mode=0o500)
    run("save-fail", folder)
    assert json.loads((folder / "settings.json").read_text())["weatherCity"] == "Москва"
    folder.chmod(0o700)
print("SETTINGS_TESTS_PASS")
