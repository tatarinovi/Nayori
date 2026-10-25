"""Isolated window/controller tests. --wayland additionally exercises only this test's Niri window."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--wayland", action="store_true")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="nwin-") as temporary:
    folder = Path(temporary)
    runtime = folder / "run"
    runtime.mkdir(mode=0o700)
    original_runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORMTHEME="basic",
               NAYORI_SETTINGS_DIR=str(folder / "config"), QT_QUICK_BACKEND="software",
               NAYORI_SETTINGS_CONFIG=str(root / "SettingsWindowSmoke.qml"))
    if args.wayland:
        display = env.get("WAYLAND_DISPLAY", "wayland-0")
        env["WAYLAND_DISPLAY"] = display if display.startswith("/") else str(Path(original_runtime) / display)
        env["QT_QPA_PLATFORM"] = "wayland"
    else:
        env["QT_QPA_PLATFORM"] = "offscreen"
        env.pop("WAYLAND_DISPLAY", None)
        env["NIRI_SOCKET"] = ""
    def run(*command, check=True):
        result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=20)
        if check:
            assert result.returncode == 0, result.stdout + result.stderr
            assert not any(word in result.stdout + result.stderr for word in
                ["WINDOW_FAIL", "ReferenceError:", "TypeError:", "Unable to assign", "Failed to load configuration"]), result.stdout + result.stderr
        return result.stdout.strip()
    def ipc(method, *values):
        return run("qs", "ipc", "-p", str(root / "SettingsWindowSmoke.qml"), "call", "settings", method, *values)
    def snapshot():
        return json.loads(ipc("snapshot"))
    def until(predicate, message):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            value = predicate()
            if value:
                return value
            time.sleep(.05)
        raise AssertionError(message)
    def windows():
        return json.loads(run("niri", "msg", "-j", "windows"))
    def owned():
        pid = snapshot()["pid"]
        return [w for w in windows() if w.get("pid") == pid and w.get("app_id") == "nayori-settings-test"
                and w.get("title") == "Nayori Settings"]
    if not args.wayland:
        output = run("qs", "-p", str(root / "SettingsWindowSmoke.qml"), "--no-color")
        print("PASS controller native-close/recreate/PID isolation")
    env["NAYORI_WINDOW_WAYLAND"] = "1"  # Persistent IPC harness, also used on offscreen.
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            list(pool.map(lambda _: run(str(root / "scripts/nayori-settings"), "--page", "weather"), range(3)))
        state = snapshot()
        assert state["opened"] and state["page"] == 3
        pid = state["pid"]
        print("PASS cold start + three parallel open requests")
        if args.wayland:
            window = until(lambda: owned(), "test window did not map")
            assert len(window) == 1
            first_id = window[0]["id"]
            until(lambda: snapshot()["id"] == first_id, "controller did not register Niri ID")
            run("niri", "msg", "action", "close-window", "--id", str(first_id))
            until(lambda: not snapshot()["opened"] and not owned(), "native close did not reset state")
            assert snapshot()["id"] == -1
            print(f"PASS Niri standard close resets exact ID {first_id}")
        else:
            ipc("close")
            assert not snapshot()["opened"]
        run(str(root / "scripts/nayori-settings"))
        assert snapshot()["pid"] == pid and snapshot()["opened"]
        if args.wayland:
            reopened = until(lambda: owned(), "reopen after native close failed")
            assert len(reopened) == 1
            second_id = reopened[0]["id"]
            until(lambda: snapshot()["id"] == second_id, "reopened identity not registered")
            for _ in range(3):
                ipc("open")
            assert len(owned()) == 1
            assert not owned()[0]["is_floating"], "must retain standard tiling"
            until(lambda: owned()[0]["is_focused"], "repeat open did not focus the existing window")
            print(f"PASS reopen + exact ID/PID + focus + no duplicates ({first_id} -> {second_id})")
            outputs = json.loads(run("niri", "msg", "-j", "outputs"))
            connected = [name for name, value in outputs.items() if value.get("logical")]
            for output in connected:
                run("niri", "msg", "action", "move-window-to-monitor", "--id", str(second_id), output)
                def on_output():
                    workspaces = json.loads(run("niri", "msg", "-j", "workspaces"))
                    current = owned()
                    return current and any(w["id"] == current[0]["workspace_id"] and w.get("output") == output for w in workspaces)
                until(on_output, "monitor move not confirmed")
                assert snapshot()["id"] == second_id
            print(f"PASS monitor moves: {', '.join(connected)}")
            before_width = owned()[0]["layout"]["window_size"][0]
            requested_width = 900 if before_width != 900 else 1100
            run("niri", "msg", "action", "set-window-width", "--id", str(second_id), str(requested_width))
            until(lambda: owned()[0]["layout"]["window_size"][0] != before_width, "resize did not change width")
            assert snapshot()["id"] == second_id
            print("PASS compositor resize")
            before = owned()[0]["layout"]["window_size"]
            run("niri", "msg", "action", "maximize-window-to-edges", "--id", str(second_id))
            until(lambda: owned()[0]["layout"]["window_size"] != before, "maximize did not change geometry")
            run("niri", "msg", "action", "maximize-window-to-edges", "--id", str(second_id))
            until(lambda: owned()[0]["layout"]["window_size"] == before, "unmaximize did not restore geometry")
            print("PASS maximize/unmaximize")
        ipc("close")
        ipc("quit")
        time.sleep(.3)
        run(str(root / "scripts/nayori-settings"), "--page", "panels")
        assert snapshot()["page"] == 1
        print("PASS restart and command reopen")
    finally:
        run("qs", "kill", "-p", str(root / "SettingsWindowSmoke.qml"), check=False)
print("SETTINGS_WINDOW_TESTS_PASS")
