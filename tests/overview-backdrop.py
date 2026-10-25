#!/usr/bin/env python3
"""Blur a fixture wallpaper and check the overview rule points at that layer."""

import importlib.util
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLUR_PATH = ROOT / "services/canvas/overview_blur.py"
RULE_PATH = ROOT / "services/niri/niri_overview.py"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


blur = load("overview_blur", BLUR_PATH)
rule = load("niri_overview", RULE_PATH)


def run(script, args):
    completed = subprocess.run(
        ["python3", str(script), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        payload = None
    return completed.returncode, payload, completed.stderr


def neighbor_contrast(path):
    image = blur.Image.open(path).convert("RGB")
    width, height = image.size
    pixels = image.load()
    total = 0
    count = 0
    for y in range(height):
        for x in range(width - 1):
            left = pixels[x, y]
            right = pixels[x + 1, y]
            total += abs(left[0] - right[0]) + abs(left[1] - right[1]) + abs(left[2] - right[2])
            count += 1
    return total / count, image.size


def stripes(path, width, height):
    pixels = []
    for _y in range(height):
        for x in range(width):
            pixels.append((255, 0, 0) if (x // 4) % 2 == 0 else (0, 0, 255))
    image = blur.Image.new("RGB", (width, height))
    image.putdata(pixels)
    image.save(path, format="PNG")


def assert_clean(directory):
    for path in directory.rglob("*"):
        name = path.name
        if name.endswith(".bak") or name.startswith(".blur-") or ".nayori-" in name:
            raise SystemExit("leftover " + str(path))


def main():
    window = (ROOT / "surfaces/canvas/OverviewWindow.qml").read_text(encoding="utf-8")
    blur_qml = (ROOT / "services/canvas/OverviewBlur.qml").read_text(encoding="utf-8")
    overview_rule = (ROOT / "services/niri/OverviewRule.qml").read_text(encoding="utf-8")
    if 'namespace: "nayori-overview"' not in window:
        raise SystemExit("window namespace")
    if "item.pointer" not in blur_qml or "slot.path" not in window:
        raise SystemExit("pointer chain")
    if overview_rule.count("Niri.reloadConfig()") != 1 or "quit" in overview_rule:
        raise SystemExit("reload policy")

    with tempfile.TemporaryDirectory(prefix="nayori-overview-", dir=ROOT) as temporary:
        root = Path(temporary)
        cache = root / "cache"
        source = root / "stripes.png"
        wide = root / "wide.png"
        stripes(source, 80, 40)
        stripes(wide, 600, 100)
        sharp, sharp_size = neighbor_contrast(source)
        request = {
            "generation": 1,
            "cacheDir": str(cache),
            "jobs": [
                {"output": "DP-1", "source": source.as_uri()},
                {"output": "DP-2", "source": wide.as_uri()},
            ],
        }
        status, payload, err = run(BLUR_PATH, ["--request", json.dumps(request)])
        if status != 0 or not payload or not payload.get("ok"):
            raise SystemExit("blur failed " + err + " " + json.dumps(payload))
        pointer = blur.take_pointer(payload, 1, "DP-1")
        wide_pointer = blur.take_pointer(payload, 1, "DP-2")
        if not pointer or blur.take_pointer(payload, 2, "DP-1") != "":
            raise SystemExit("stale generation was accepted")
        soft, soft_size = neighbor_contrast(pointer)
        wide_size = blur.Image.open(wide_pointer).size
        if soft >= sharp * 0.5:
            raise SystemExit("blur did not soften contrast " + str(soft) + " vs " + str(sharp))
        if soft_size != sharp_size:
            raise SystemExit("small fixture was resized " + str(soft_size))
        if max(wide_size) != blur.MAX_EDGE or wide_size != (480, 80):
            raise SystemExit("wide fixture edge " + str(wide_size))
        again = dict(request)
        status, second, err = run(BLUR_PATH, ["--request", json.dumps(again)])
        if status != 0 or not second["outputs"]["DP-1"]["cached"] or second["outputs"]["DP-1"]["pointer"] != pointer:
            raise SystemExit("cache miss on unchanged file")
        os.utime(source, (source.stat().st_atime, source.stat().st_mtime + 5))
        request["generation"] = 3
        status, third, err = run(BLUR_PATH, ["--request", json.dumps(request)])
        moved = blur.take_pointer(third, 3, "DP-1")
        if not moved or moved == pointer:
            raise SystemExit("mtime did not regenerate")
        if not Path(pointer).is_file():
            raise SystemExit("previous blur was removed")
        corrupt = root / "corrupt.png"
        corrupt.write_bytes(b"not an image")
        request["generation"] = 4
        request["jobs"] = [{"output": "DP-1", "source": corrupt.as_uri()}]
        status, failed, err = run(BLUR_PATH, ["--request", json.dumps(request)])
        if status != 0 or failed["outputs"]["DP-1"]["ok"] is not False:
            raise SystemExit("corrupt image should fail softly")
        if not Path(moved).is_file() or not Path(pointer).is_file():
            raise SystemExit("failed blur removed a cached file")
        assert_clean(cache)
        print("OVERVIEW_POINTER " + moved)

        config_dir = root / "niri"
        (config_dir / "cfg").mkdir(parents=True)
        keybinds = config_dir / "cfg" / "keybinds.kdl"
        keybinds.write_text(
            "binds {\n"
            "    Alt+Space hotkey-overlay-title=\"App Launcher\" { spawn-sh \"qs ipc call launcher toggle\"; }\n"
            "}\n",
            encoding="utf-8",
        )
        noctalia = config_dir / "noctalia.kdl"
        noctalia.write_text("layout {\n}\n", encoding="utf-8")
        accent = config_dir / "nayori-accent.kdl"
        accent.write_text("layout {\n}\n", encoding="utf-8")
        config = config_dir / "config.kdl"
        original = (
            "include \"cfg/keybinds.kdl\"\n"
            "\n"
            "// keep-alt-space-marker\n"
            "include \"nayori-accent.kdl\"\n"
        )
        config.write_text(original, encoding="utf-8")
        key_bytes = keybinds.read_bytes()
        noctalia_bytes = noctalia.read_bytes()
        accent_bytes = accent.read_bytes()
        status, planned, err = run(RULE_PATH, ["--dry-run", "--config", str(config)])
        if status != 0 or not planned.get("ok") or not planned.get("changed") or planned.get("namespace") != "nayori-overview":
            raise SystemExit("dry-run " + json.dumps(planned) + err)
        if (config_dir / "nayori-overview.kdl").exists():
            raise SystemExit("dry-run wrote the fragment")
        status, applied, err = run(
            RULE_PATH, ["--apply", "--skip-validate", "--config", str(config)]
        )
        if status != 0 or not applied.get("ok") or not applied.get("changed") or applied.get("backups") != []:
            raise SystemExit("apply " + json.dumps(applied) + err)
        written = config.read_text(encoding="utf-8")
        expected = original.replace(
            "include \"nayori-accent.kdl\"\n",
            "include \"nayori-accent.kdl\"\ninclude \"nayori-overview.kdl\"\n",
            1,
        )
        if written != expected:
            raise SystemExit("config.kdl changed more than the include\n" + written)
        fragment = (config_dir / "nayori-overview.kdl").read_text(encoding="utf-8")
        if "namespace=\"^nayori-overview$\"" not in fragment or "place-within-backdrop true" not in fragment:
            raise SystemExit("fragment missing backdrop rule")
        if "backdrop-image" in fragment or moved in fragment:
            raise SystemExit("fragment invented an image path")
        if keybinds.read_bytes() != key_bytes or b"Alt+Space" not in key_bytes:
            raise SystemExit("Alt+Space binding changed")
        if noctalia.read_bytes() != noctalia_bytes or accent.read_bytes() != accent_bytes:
            raise SystemExit("owned files were rewritten")
        status, refused, err = run(RULE_PATH, ["--apply", "--skip-validate", "--config", str(noctalia)])
        if refused.get("ok") is not False or noctalia.read_bytes() != noctalia_bytes:
            raise SystemExit("noctalia was writable")
        status, repeat, err = run(RULE_PATH, ["--apply", "--skip-validate", "--config", str(config)])
        if status != 0 or repeat.get("changed") is not False or config.read_text(encoding="utf-8") != expected:
            raise SystemExit("second apply rewrote config")
        future = os.path.getmtime(config) + 30
        if not rule.rule_is_live(config, config_dir / "nayori-overview.kdl", future, None):
            raise SystemExit("rule should be live when niri starts after the write")
        if rule.rule_is_live(config, config_dir / "nayori-overview.kdl", 1, None):
            raise SystemExit("rule must stay dark before niri loads it")
        if not rule.rule_is_live(config, config_dir / "nayori-overview.kdl", None, future):
            raise SystemExit("observed reload should publish the rule")
        saved_cache = os.environ.get("XDG_CACHE_HOME")
        os.environ["XDG_CACHE_HOME"] = str(root / "stamp-home")
        try:
            if rule.rule_is_live(config, config_dir / "nayori-overview.kdl", 1, None):
                raise SystemExit("stamp must not leak")
            rule.remember(config, config_dir / "nayori-overview.kdl")
            if not rule.rule_is_live(config, config_dir / "nayori-overview.kdl", 1, None):
                raise SystemExit("remembered load should map")
        finally:
            if saved_cache is None:
                os.environ.pop("XDG_CACHE_HOME", None)
            else:
                os.environ["XDG_CACHE_HOME"] = saved_cache
        assert_clean(config_dir)

        probe = root / "probe"
        probe.mkdir()
        good = probe / "config.kdl"
        good_fragment = probe / "nayori-overview.kdl"
        good_fragment.write_text(rule.FRAGMENT_TEXT, encoding="utf-8")
        good.write_text("include \"nayori-overview.kdl\"\n", encoding="utf-8")
        checked = subprocess.run(
            ["niri", "validate", "-c", str(good)],
            check=False,
            capture_output=True,
            text=True,
        )
        if checked.returncode != 0:
            raise SystemExit("niri rejected the backdrop rule\n" + checked.stderr)
        bad = probe / "bad.kdl"
        bad.write_text("overview {\n    backdrop-image \"x\"\n}\n", encoding="utf-8")
        rejected = subprocess.run(
            ["niri", "validate", "-c", str(bad)],
            check=False,
            capture_output=True,
            text=True,
        )
        if rejected.returncode == 0:
            raise SystemExit("this niri unexpectedly accepted backdrop-image")
        print("OVERVIEW_RULE nayori-overview place-within-backdrop")
        print("OVERVIEW_BACKDROP_PASS")


if __name__ == "__main__":
    main()
