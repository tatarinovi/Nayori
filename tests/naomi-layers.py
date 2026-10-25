#!/usr/bin/env python3
"""Слои анимированной Naomi: манифест совпадает с файлами, размеры в пределах источника."""
import json
import pathlib
import re
import struct

root = pathlib.Path(__file__).resolve().parent.parent
js = (root / "surfaces/companion/NaomiLayers.js").read_text()
width = int(re.search(r"var width = (\d+)", js).group(1))
height = int(re.search(r"var height = (\d+)", js).group(1))
layers = json.loads(re.search(r"var layers = (\{.*\});", js, re.S).group(1))
need = {"body_lower", "body_torso", "head", "ear_left", "ear_right", "lid_left", "lid_right",
        "pin_dangle", "pin_moon", "scarf_neck", "scarf_1", "scarf_2", "scarf_3",
        "hair_left_1", "hair_left_2", "hair_left_3", "hair_right_1", "hair_right_2"}
assert need <= set(layers), need - set(layers)
assert "moon" not in layers, "большая луна убрана из слоёв"
assert not list((root / "assets/naomi/layers").glob("moon*")), "файл слоя moon удалён"
for name, info in layers.items():
    path = root / "assets/naomi/layers" / info["file"]
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", name
    w, h = struct.unpack(">II", data[16:24])
    assert (w, h) == (info["w"], info["h"]), f"{name}: размер PNG не совпадает с манифестом"
    assert info["x"] >= 0 and info["y"] >= 0 and info["x"] + w <= width and info["y"] + h <= height, name
print("NAOMI_LAYERS_PASS", len(layers))
