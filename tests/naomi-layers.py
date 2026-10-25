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

# --- слои эмоций (поглаживание) ---
emotions = {"eye_happy_left", "eye_happy_right", "mouth_smile", "blush_left", "blush_right"}
assert emotions <= set(layers), emotions - set(layers)
manifest = json.loads((root / "assets/naomi/layers/layers.json").read_text())
by_name = {m["name"]: m for m in manifest["layers"]}
assert set(by_name) == set(layers), "layers.json и NaomiLayers.js описывают один набор слоёв"
for name, info in layers.items():
    m = by_name[name]
    assert all(m[k] == info[k] for k in ("file", "x", "y", "w", "h")), f"{name}: layers.json и NaomiLayers.js расходятся"
head = layers["head"]
for name in emotions:
    info = layers[name]
    assert head["x"] <= info["x"] and info["x"] + info["w"] <= head["x"] + head["w"], f"{name}: слой вне головы по x"
    assert head["y"] <= info["y"] and info["y"] + info["h"] <= head["y"] + head["h"], f"{name}: слой вне головы по y"


def pixels(name):
    """Читает PNG слоя в массив RGBA (нужны Pillow и numpy, как у генератора)."""
    from PIL import Image
    import numpy as np
    return np.asarray(Image.open(root / "assets/naomi/layers" / layers[name]["file"]).convert("RGBA"))


try:
    import numpy as np
    have_pixels = True
except ImportError:
    have_pixels = False
if have_pixels:
    for name in ("eye_happy_left", "eye_happy_right"):
        px = pixels(name)
        solid = px[..., 3] > 200
        assert 20 < solid.sum() < 400, f"{name}: дуга глаза нарисована ({solid.sum()} пикселей)"
        assert px[solid][:, :3].max() < 60, f"{name}: тёмные ресницы"
        ys = np.nonzero(solid)[0]
        assert ys.min() >= 2 and ys.max() <= px.shape[0] - 3, f"{name}: дуга не обрезана краем слоя"
    for name in ("blush_left", "blush_right"):
        px = pixels(name)
        assert (px[px[..., 3] > 0][:, :3] > 250).all(), f"{name}: белая маска под перекраску цветом secondary"
        alpha = px[..., 3]
        assert 60 < alpha.max() < 200 and alpha[0, 0] == 0 and alpha[-1, -1] == 0, f"{name}: мягкое пятно с прозрачным краем"
        edge = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
        assert edge.max() <= 2, f"{name}: пятно не упирается в край слоя"
    smile = pixels("mouth_smile")
    assert (smile[..., 3] > 200).sum() > 30 and smile[..., 3].max() == 255, "mouth_smile: кожа поверх закрытого рта и линия улыбки"

# --- QML использует все слои и не содержит hex-цветов ---
qml = (root / "surfaces/companion/NaomiIllustration.qml").read_text()
for name in layers:
    assert f'atlasName: "{name}"' in qml, f"{name}: слой не подключён в NaomiIllustration.qml"
for path in list((root / "surfaces/companion").glob("*.qml")) + list((root / "services/companion").glob("*.qml")):
    code = "\n".join(line.split("//")[0] for line in path.read_text().splitlines())
    assert not re.search(r"#[0-9A-Fa-f]{3,8}\b", code), f"{path.name}: hex-цвет в QML"
assert (root / "assets/naomi/candidates/naomi-variant-c-graphic.jpg").exists(), "источник слоёв на месте"
print("NAOMI_LAYERS_PASS", len(layers))
