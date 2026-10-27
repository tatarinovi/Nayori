"""Verify the supplied ten-layer atlas and run the real QML idle prototype."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
from PIL import Image

root = Path(__file__).resolve().parents[1]
atlas = root / "assets/naomi/v3"
manifest = json.loads((atlas / "manifest.json").read_text())
assert len(manifest["z_order_back_to_front"]) == 10
for name in manifest["z_order_back_to_front"]:
    with Image.open(atlas / (name + ".png")) as image:
        assert image.mode == "RGBA" and image.size == (305, 1024), name
with tempfile.TemporaryDirectory(prefix="nsv3-") as directory:
    runtime = Path(directory) / "run"
    runtime.mkdir(mode=0o700)
    output = Path(directory) / "sprite.png"
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen",
               QT_QPA_PLATFORMTHEME="basic", QT_QUICK_BACKEND="software", QS_DISABLE_FILE_WATCHER="1",
               NAYORI_SPRITE_OUTPUT=str(output))
    run = subprocess.run(["qs", "-p", str(root / "tests/smoke/NaomiSpriteSmoke.qml"), "--no-color"],
                         env=env, capture_output=True, text=True, timeout=18)
    log = run.stdout + run.stderr
    assert run.returncode == 0 and "NAOMI_SPRITE_PASS" in log, log
    assert not any(error in log for error in ["NAOMI_SPRITE_FAIL", "ReferenceError", "TypeError", "Unable to assign", "Binding loop", "Cannot open"]), log
    with Image.open(output).convert("RGBA") as image:
        assert image.size == (280, 534)
        assert all(image.getpixel(point)[3] == 0 for point in [(0, 0), (279, 0), (0, 533), (279, 533)]), "transparent background"
        assert image.getchannel("A").getbbox() is not None, "character is visible"
print("NAOMI_SPRITE_TESTS_PASS transparent-canvas ten-assets idle stop-start styles")
