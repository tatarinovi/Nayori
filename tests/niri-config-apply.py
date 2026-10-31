#!/usr/bin/env python3
"""Isolated checks for niri config edits. Never reloads a live session."""

import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services/system"))
import niri_config_apply as nca

FIXTURE = ROOT / "tests/fixtures/niri-devices"
ACCEPT = lambda _path: True


def copy_fixture(destination):
    target = Path(destination)
    shutil.copytree(FIXTURE, target, dirs_exist_ok=True)
    return target / "config.kdl"


def read(path):
    return Path(path).read_text(encoding="utf-8")


def assert_true(condition, message):
    if not condition:
        raise SystemExit(message)


def test_parser_accepts_shipped_presets():
    for path in (ROOT / "configs/niri").rglob("*.kdl"):
        nca.parse_document(path.read_text(encoding="utf-8"))
    print("PASS parser accepts shipped niri presets")


def test_comment_and_outputs():
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        base = Path(directory)
        outputs = base / "cfg/outputs.kdl"
        before_hdmi = "output \"HDMI-A-1\" {\n    // unusual block\n    mode \"1280x720\"\n    background-color \"#101010\"\n    focus-at-startup\n}\n"
        assert_true(before_hdmi in read(outputs), "fixture lost the unusual output")
        result = nca.apply_changes(config, {
            "output": {
                "name": "DP-1",
                "set": {
                    "mode": "2560x1440@144",
                    "scale": 1.5,
                    "position": {"x": 1920, "y": 0},
                    "transform": "90",
                },
            },
        }, validator=ACCEPT)
        assert_true(result["ok"] and result["changed"], "output edit failed: " + result["error"])
        text = read(outputs)
        expected = """// outputs header
output "DP-1" {
    // keep inside dp1
    mode "2560x1440@144" // old refresh
    scale 1.5
    position x=1920 y=0
    transform "90"
}

/-output "DP-1" {
    scale 9
}

output "HDMI-A-1" {
    // unusual block
    mode "1280x720"
    background-color "#101010"
    focus-at-startup
}
"""
        assert_true(text == expected, "output edit was not surgical:\n" + text)
        assert_true(read(base / "noctalia.kdl").startswith("// do not touch"), "noctalia changed")
        assert_true(read(base / "cfg/input.kdl").startswith("// input header"), "input changed")
        assert_true(read(config) == read(FIXTURE / "config.kdl"), "root config changed")
        state = nca.read_config(config)
        dp = [item for item in state["outputs"] if item["name"] == "DP-1" and item["editable"]]
        assert_true(dp and dp[0]["scale"] == 1.5 and dp[0]["transform"] == "90", "readback mismatch")
        assert_true(any(item["name"] == "HDMI-A-1" and item["mode"] == "1280x720" for item in state["outputs"]), "hdmi dropped")
        assert_true(any(item["name"] == "NOCT-1" and item["editable"] is False for item in state["outputs"]), "protected output not marked")
    print("PASS comment preservation and multi-output edit")


def test_keyboard_mouse_touchpad():
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        input_path = Path(directory) / "cfg/input.kdl"
        result = nca.apply_changes(config, {
            "keyboard": {"set": {
                "layout": "us,ru,de",
                "variant": ",winkeys,",
                "repeat-delay": 400,
                "repeat-rate": 30,
                "track-layout": "window",
                "numlock": True,
            }},
        }, validator=ACCEPT)
        assert_true(result["ok"] and result["changed"], result["error"])
        text = read(input_path)
        assert_true('layout "us,ru,de"' in text, text)
        assert_true('variant ",winkeys,"' in text, text)
        assert_true('options "grp:win_space_toggle"' in text, "options line dropped:\n" + text)
        assert_true("// layout note" in text and "// repeat stays until edited" in text, text)
        assert_true("focus-follows-mouse" in text and "workspace-auto-back-and-forth" in text, text)
        assert_true("\n        numlock\n" in text or text.count("numlock") == 1, text)
        mouse = nca.apply_changes(config, {
            "mouse": {"set": {"accel-speed": -0.2, "natural-scroll": True, "accel-profile": "adaptive"}},
            "touchpad": {"set": {"tap": False, "dwt": True, "drag": False, "scroll-method": "edge"}},
        }, validator=ACCEPT)
        assert_true(mouse["ok"] and mouse["changed"], mouse["error"])
        text = read(input_path)
        assert_true("accel-speed -0.2" in text, text)
        assert_true("natural-scroll" in text, text)
        assert_true('accel-profile "adaptive"' in text, text)
        assert_true("// Enable tap-to-click" in text, "tap comment dropped:\n" + text)
        assert_true("\n        tap\n" not in text and "\n        tap " not in text, "tap node remained:\n" + text)
        assert_true("dwt" in text and "drag false" in text and 'scroll-method "edge"' in text, text)
        assert_true("natural-scroll // Enable natural scrolling" in text, text)
        rejected = nca.apply_changes(config, {"mouse": {"set": {"scroll-speed": 2}}}, validator=ACCEPT)
        assert_true(not rejected["ok"], "unsupported key was accepted")
        assert_true(read(input_path) == text, "unsupported key changed the file")
        same = nca.apply_changes(config, {"mouse": {"set": {"accel-speed": -0.2}}}, validator=ACCEPT)
        assert_true(same["ok"] and not same["changed"], "equal value was rewritten")
    print("PASS keyboard, mouse, touchpad, unsupported key")


def test_rollback_and_write_error():
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        outputs = Path(directory) / "cfg/outputs.kdl"
        original = read(outputs)
        denied = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {"transform": "180"}},
        }, validator=lambda _path: False)
        assert_true(not denied["ok"] and denied["rolledBack"], denied["error"])
        assert_true(read(outputs) == original, "validate failure left the edit in place")
        assert_true(denied["backups"] and Path(denied["backups"][0]).read_text(encoding="utf-8") == original, "backup is not the original")
        bad = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {"transform": "sideways"}},
        }, validator=ACCEPT)
        assert_true(not bad["ok"] and read(outputs) == original, "bad transform was written")
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        outputs = Path(directory) / "cfg/outputs.kdl"
        original = read(outputs)
        folder = Path(directory)
        folder.chmod(0o500)
        try:
            failed = nca.apply_changes(config, {
                "output": {"name": "DP-1", "set": {"scale": 2}},
            }, validator=ACCEPT)
        finally:
            folder.chmod(0o700)
        assert_true(not failed["ok"], "read-only directory was treated as success")
        assert_true(read(outputs) == original, "read-only apply changed the file")
    print("PASS backup, validate rollback, write error")


def test_confirm_timer_without_live_reload():
    calls = []
    original = nca.live_reload
    nca.live_reload = lambda: calls.append("live") or {"ok": True}
    try:
        with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
            config = copy_fixture(directory)
            outputs = Path(directory) / "cfg/outputs.kdl"
            original_text = read(outputs)
            moment = 1_700_000_000
            first = nca.apply_changes(config, {
                "output": {"name": "DP-1", "set": {"scale": 1.25}},
            }, now=moment, validator=ACCEPT)
            assert_true(first["ok"] and first["pending"], "display change did not ask for confirmation")
            pending_id = first["pending"]["id"]
            assert_true("scale 1.25" in read(outputs), "scale was not written")
            early = nca.expire_pending(config, now=moment + 5)
            assert_true(early["ok"] and not early["rolledBack"] and "scale 1.25" in read(outputs), "timer rolled back too early")
            second = nca.apply_changes(config, {
                "output": {"name": "HDMI-A-1", "set": {"scale": 2}},
            }, now=moment + 6, validator=ACCEPT)
            assert_true(second["ok"] and "scale 2" in read(outputs), second["error"])
            blocked = nca.apply_changes(config, {
                "mouse": {"set": {"accel-speed": 0.4}},
            }, validator=ACCEPT)
            # Mouse lives in another file, so it stays allowed.
            assert_true(blocked["ok"], blocked["error"])
            expired = nca.expire_pending(config, now=moment + 6 + nca.CONFIRM_SECONDS + 1)
            assert_true(expired["rolledBack"], "timer did not roll back")
            assert_true(read(outputs) == original_text, "rollback did not restore every output edit:\n" + read(outputs))
            again = nca.apply_changes(config, {
                "output": {"name": "DP-1", "set": {"scale": 2}},
            }, now=moment, validator=ACCEPT)
            kept = nca.confirm_pending(config, again["pending"]["id"])
            assert_true(kept["ok"] and not kept.get("pending"), kept["error"])
            later = nca.expire_pending(config, now=moment + 1000)
            assert_true(not later["rolledBack"] and "scale 2" in read(outputs), "confirmed change was rolled back")
            assert_true(calls == [], "live reload was invoked: %s" % calls)
            assert_true(pending_id, "missing pending id")
    finally:
        nca.live_reload = original
    print("PASS confirm timer without live reload")


def test_real_validate():
    if nca.niri_binary() is None:
        print("SKIP niri validate checks: command niri not found")
        return
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        bad = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {"transform": "sideways"}},
        })
        assert_true(not bad["ok"], "niri accepted an invalid transform")
        outputs = Path(directory) / "cfg/outputs.kdl"
        assert_true('transform "normal"' in read(outputs), "invalid transform stayed in the file")
        good = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {"scale": 1.75, "mode": "1920x1080@60"}},
            "keyboard": {"set": {"layout": "us,ru"}},
            "touchpad": {"set": {"click-method": "clickfinger"}},
        })
        assert_true(good["ok"] and good["changed"], good["error"])
        assert_true("scale 1.75" in read(outputs), read(outputs))
        assert_true('click-method "clickfinger"' in read(Path(directory) / "cfg/input.kdl"), "touchpad key missing")
    print("PASS niri validate on a temporary config")


def test_protected_and_missing_output():
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        noctalia = Path(directory) / "noctalia.kdl"
        before = read(noctalia)
        refused = nca.apply_changes(config, {
            "output": {"name": "NOCT-1", "set": {"scale": 1}},
        }, validator=ACCEPT)
        assert_true(not refused["ok"] and read(noctalia) == before, refused["error"] or "protected output was edited")
        created = nca.apply_changes(config, {
            "output": {"name": "eDP-1", "set": {"mode": "1920x1200@60", "scale": 1.25}},
        }, validator=ACCEPT)
        assert_true(created["ok"], created["error"])
        root = read(config)
        assert_true('output "eDP-1"' in root and "include \"cfg/outputs.kdl\"" in root, root)
        assert_true(read(Path(directory) / "cfg/outputs.kdl").count('output "HDMI-A-1"') == 1, "existing outputs were rewritten")
    print("PASS protected file and new output")


def test_primary_moves_focus_line():
    with tempfile.TemporaryDirectory(prefix="niri-devices-") as directory:
        config = copy_fixture(directory)
        outputs = Path(directory) / "cfg/outputs.kdl"
        result = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {}, "primary": True, "primaryName": "DP-1"},
        }, validator=ACCEPT)
        assert_true(result["ok"] and result["changed"], result["error"] or "primary was not written")
        text = read(outputs)
        assert_true("focus-at-startup" in text.split("HDMI-A-1")[0], "DP-1 did not become primary:\n" + text)
        hdmi = text.split("output \"HDMI-A-1\"", 1)[1]
        assert_true("focus-at-startup" not in hdmi, "old primary kept the line:\n" + text)
        assert_true("background-color \"#101010\"" in hdmi, "unrelated line was dropped")
        assert_true("// keep inside dp1" in text and "// unusual block" in text, "comments were dropped")
        again = nca.apply_changes(config, {
            "output": {"name": "DP-1", "set": {}, "primary": True, "primaryName": "DP-1"},
        }, validator=ACCEPT)
        assert_true(again["ok"] and not again["changed"], "repeating the same primary rewrote the file")
    print("PASS primary output")


def main():
    test_parser_accepts_shipped_presets()
    test_comment_and_outputs()
    test_keyboard_mouse_touchpad()
    test_rollback_and_write_error()
    test_confirm_timer_without_live_reload()
    test_protected_and_missing_output()
    test_primary_moves_focus_line()
    test_real_validate()
    print("OK")


if __name__ == "__main__":
    main()
