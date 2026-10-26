"""Nested compositor: real layer mapping and keyboard focus, no clipboard access."""
import os
import json
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
host_display = os.environ.get("WAYLAND_DISPLAY", "")
if host_display and not host_display.startswith("/"):
    host_display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / host_display)
assert host_display and Path(host_display).exists(), "Wayland session required"

with tempfile.TemporaryDirectory(prefix="nayori-clipboard-wayland-") as directory:
    temporary = Path(directory)
    runtime = temporary / "runtime"
    runtime.mkdir(mode=0o700)
    config = temporary / "niri.kdl"
    config.write_text('input { keyboard { xkb { layout "us"; }; }; }\n')
    env = {k: v for k, v in os.environ.items() if k not in ("NIRI_SOCKET", "DISPLAY", "WAYLAND_DEBUG")}
    env.update(XDG_RUNTIME_DIR=str(runtime), HOME=str(temporary), XDG_CONFIG_HOME=str(temporary / "config"),
               QT_QPA_PLATFORMTHEME="basic", QS_DISABLE_FILE_WATCHER="1",
               DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(temporary / "no-bus"))
    compositor = shell = None
    log = temporary / "shell.log"
    def wait_for(predicate, what, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(0.1)
        raise AssertionError(what + "\n" + (log.read_text() if log.exists() else ""))
    try:
        compositor = subprocess.Popen(["niri", "-c", str(config)], env=dict(env, WAYLAND_DISPLAY=host_display),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        wait_for(lambda: (runtime / "wayland-1").exists() and list(runtime.glob("niri.*.sock")), "Nested niri")
        nested = dict(env, WAYLAND_DISPLAY="wayland-1", QT_QPA_PLATFORM="wayland", WAYLAND_DEBUG="client",
                      NIRI_SOCKET=str(next(runtime.glob("niri.*.sock"))))
        scene = str(ROOT / "tests/smoke/ClipboardWindowSmoke.qml")
        with log.open("w") as sink:
            shell = subprocess.Popen(["qs", "-p", scene, "--no-color"], env=nested,
                                     stdout=sink, stderr=subprocess.STDOUT, start_new_session=True)
        wait_for(lambda: "Configuration Loaded" in log.read_text(), "QML loaded")
        def ipc(action):
            result = subprocess.run(["qs", "ipc", "-p", scene, "call", "clipboard_test", action],
                                    env=nested, capture_output=True, text=True, timeout=5)
            assert result.returncode == 0, result.stderr
            return result.stdout.strip()
        def toggle():
            ipc("toggle")
        def state():
            return json.loads(ipc("state"))
        for attempt in range(2):
            mark = len(log.read_text())
            toggle()
            match = wait_for(lambda: re.search(
                r'get_layer_surface\(new id (zwlr_layer_surface_v1#\d+), (wl_surface#\d+), [^)]*"nayori-clipboard"\)',
                log.read_text()[mark:]), "Clipboard layer surface")
            layer, surface = match.group(1), match.group(2)
            wait_for(lambda: re.search(r"wl_keyboard#\d+\.enter\(\d+, " + surface + ",", log.read_text()[mark:]),
                     "Keyboard focus without hovering")
            opened = log.read_text()[mark:]
            assert "CLIPBOARD_WINDOW_ANCHOR" in opened
            assert re.search(re.escape(layer) + r"\.set_keyboard_interactivity\(1\)", opened)
            assert not any(problem in opened for problem in ("TypeError", "ReferenceError", "Unable to assign", "Error:")), opened
            wait_for(lambda: state()["reveal"] == 1 and state()["focused"], "Visible and focused panel")
            assert state()["x"] >= 12 and state()["y"] >= 12
            if attempt == 0:
                created = state()["created"]
                toggle()
                closing = state()
                assert closing["presenting"] and 0 < closing["reveal"] <= 1, closing
                assert abs(closing["blurHeight"] - round(closing["fullHeight"] * closing["reveal"])) <= 1, closing
                toggle()  # Reverse the exit; keep the same window and anchor.
                wait_for(lambda: state()["reveal"] == 1, "Interrupted exit reopened")
                assert state()["created"] == created
            else:
                ipc("reduce")
            mark = len(log.read_text())
            toggle()
            wait_for(lambda: re.search(re.escape(surface) + r"\.destroy\(\)", log.read_text()[mark:]),
                     "Clipboard surface destroyed on close")
            closed = log.read_text()[mark:]
            assert "CLIPBOARD_CLEAR_FRAME_PASS" in closed
            effect = re.search(r'get_background_effect\(new id (ext_background_effect_surface_v1#\d+), '
                               + re.escape(surface) + r'\)', opened)
            assert effect, "Frosted test must exercise compositor blur"
            cleared = re.search(re.escape(effect.group(1)) + r'\.(?:set_blur_region\(nil\)|destroy\(\))', closed)
            assert cleared, "Blur was not cleared over Wayland before destroying the layer"
            committed = closed.find(surface + ".commit()", cleared.end())
            destroyed = closed.find(surface + ".destroy()")
            assert cleared.start() < committed < destroyed, "Empty blur must be committed before surface destruction"
        # Only this nested compositor sees the clipboard fixture and Ctrl+V.
        subprocess.run(["wl-copy", "--type", "text/plain;charset=utf-8"], input=b"Nayori isolated paste fixture",
                       env={k:v for k,v in nested.items() if k != "WAYLAND_DEBUG"}, check=True, timeout=5,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        paste = subprocess.run(["python3", str(ROOT / "services/clipboard/paste_shortcut.py")],
                               env=nested, capture_output=True, text=True, timeout=5)
        assert paste.returncode == 0, paste.stderr
        wait_for(lambda: "CLIPBOARD_PASTE_TARGET_PASS" in log.read_text(), "Actual paste into the restored target")
        print("CLIPBOARD_WINDOW_TESTS_PASS")
    finally:
        for process in (shell, compositor):
            if process and process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
