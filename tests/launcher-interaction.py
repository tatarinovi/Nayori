"""Exercise empty-query launcher selection and activation in an isolated Qt session."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="nayori-launcher-interaction-") as directory:
    base = Path(directory)
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    applications = base / "data" / "applications"
    applications.mkdir(parents=True)
    for ident in ("alpha", "beta"):
        (applications / f"{ident}.desktop").write_text(
            f"[Desktop Entry]\nType=Application\nName=Example {ident}\nExec=/bin/true\n")
    state = base / "state" / "nayori"
    state.mkdir(parents=True)
    (state / "launcher-usage.json").write_text(json.dumps({
        "version": 1, "counts": {"alpha.desktop": 2, "beta.desktop": 1},
        "lastVisited": {"alpha.desktop": 1, "beta.desktop": 2},
    }))
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="basic",
               QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1", HOME=str(base),
               XDG_RUNTIME_DIR=str(runtime), XDG_DATA_HOME=str(base / "data"),
               XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
               XDG_STATE_HOME=str(base / "state"))
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    try:
        result = subprocess.run(["qs", "-p", str(root / "tests/smoke/LauncherInteractionSmoke.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired as error:
        raise AssertionError(f"launcher smoke timed out: {error.stdout} {error.stderr}") from error
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "LAUNCHER_INTERACTION_PASS" in output, output
    assert not any(token in output for token in ("ReferenceError", "TypeError", "Error:")), output
print("PASS launcher interaction: keyboard and pointer activation with empty query")
