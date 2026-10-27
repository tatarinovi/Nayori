"""Nested Niri: frozen-frame editor, focus, shortcuts, blur preview and PNG save.

The nested compositor contains only fixtures; wl-copy is replaced, so the real
desktop and clipboard are untouched. GPU recording is tested by capture.py.
"""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
display = os.environ.get("WAYLAND_DISPLAY", "")
if display and not display.startswith("/"):
    display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
assert display and Path(display).exists(), "Wayland session required"
with tempfile.TemporaryDirectory(prefix="nayori-capture-wayland-") as directory:
    folder = Path(directory)
    runtime = folder / "runtime"
    runtime.mkdir(mode=0o700)
    tools = folder / "bin"
    tools.mkdir()
    (tools / "wl-copy").write_text("#!/bin/sh\ncat > \"$NAYORI_CAPTURE_TEST_DIR/clipboard.png\"\n")
    (tools / "wl-copy").chmod(0o755)
    config = folder / "niri.kdl"
    config.write_text('input { keyboard { xkb { layout "us"; }; }; }\n')
    env = {key: value for key, value in os.environ.items() if key not in ("NIRI_SOCKET", "DISPLAY", "WAYLAND_DEBUG")}
    env.update(XDG_RUNTIME_DIR=str(runtime), HOME=directory, XDG_CONFIG_HOME=str(folder / "config"),
        QT_QPA_PLATFORMTHEME="basic", QS_DISABLE_FILE_WATCHER="1", NAYORI_CAPTURE_TEST_DIR=directory,
        PATH=str(tools) + os.pathsep + env["PATH"], DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(folder / "no-bus"))
    compositor = shell = None
    log = folder / "shell.log"
    def until(predicate, name, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(.08)
        raise AssertionError(name + "\n" + (log.read_text() if log.exists() else ""))
    try:
        compositor = subprocess.Popen(["niri", "-c", str(config)], env=dict(env, WAYLAND_DISPLAY=display),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        until(lambda: list(runtime.glob("niri.*.sock")) and (runtime / "wayland-1").exists(), "nested niri")
        nested = dict(env, WAYLAND_DISPLAY="wayland-1", QT_QPA_PLATFORM="wayland", NIRI_SOCKET=str(next(runtime.glob("niri.*.sock"))))
        scene = str(ROOT / "tests/smoke/CaptureWindowSmoke.qml")
        with log.open("w") as sink:
            shell = subprocess.Popen(["qs", "-p", scene, "--no-color"], env=nested, stdout=sink, stderr=subprocess.STDOUT, start_new_session=True)
        until(lambda: "Configuration Loaded" in log.read_text(), "QML loaded")
        def ipc(action):
            response = subprocess.run(["qs", "ipc", "-p", scene, "call", "capture_test", action], env=nested, capture_output=True, text=True, timeout=5)
            assert response.returncode == 0, response.stdout + response.stderr
            return response.stdout.strip()
        def state():
            return json.loads(ipc("snapshot"))
        until(lambda: state()["ready"], "worker ready")
        ipc("begin")
        until(lambda: state()["state"] == "select", "selection overlay")
        ipc("selectArea"); ipc("annotate"); ipc("keys")
        assert state()["state"] == "edit" and state()["marks"] == 4, state()
        # Force a compositor frame and retain a preview only inside this test's temp directory.
        time.sleep(.3)
        subprocess.run(["grim", str(folder / "editor.png")], env=nested, check=True, capture_output=True)
        ipc("save")
        until(lambda: state()["state"] == "idle", "export finished")
        final = state()
        assert final["notifications"] and "скопирован" in final["notifications"][0]["summary"], final
        paths = list((folder / "shots").glob("*.png"))
        assert len(paths) == 1 and (folder / "clipboard.png").read_bytes() == paths[0].read_bytes()
        with Image.open(paths[0]) as shot:
            assert shot.width > 0 and abs(shot.width / shot.height - 400 / 240) < .01
        ipc("begin")
        until(lambda: state()["state"] == "select", "second capture")
        ipc("cancel")
        until(lambda: state()["state"] == "idle", "cancel")
        output = log.read_text()
        assert not any(word in output for word in ("ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Error:", "Failed to load")), output
        print("CAPTURE_WINDOW_PASS: Wayland layer, focus, A/R/T/B, undo/redo, blur preview, export, clipboard MIME, notification, cancel")
    finally:
        for proc in (shell, compositor):
            if proc and proc.poll() is None:
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL); proc.wait()
