#!/usr/bin/env python3
"""Cut the haori Naomi painting into a shared-canvas sprite.

Every visible source pixel is kept on exactly one layer, so the rest pose
composites back to the painting. Layers also carry a few pixels of hidden
colour under the parts in front of them, so a small idle motion does not open
holes. A separate eyes_closed layer is drawn for the blink and is empty at rest.
"""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/naomi/haori/source.png"
OUT = ROOT / "assets/naomi/haori"

# Crop keeps the full figure and drops the empty left margin.
X0, WIDTH, HEIGHT = 148, 470, 1024

Z_ORDER = [
    "legs",
    "hair_back",
    "body",
    "clothing",
    "coat",
    "head",
    "arm",
    "hair_front",
    "hand",
    "ribbons",
    "eyes",
    "mouth",
]
# How far (px) a layer may extend under the parts drawn later.
UNDERPAINT = {
    "legs": 14,
    "hair_back": 10,
    "body": 12,
    "clothing": 10,
    "coat": 8,
    "head": 12,
    "arm": 6,
    "hair_front": 6,
    "hand": 5,
    "ribbons": 8,
    "eyes": 0,
    "mouth": 0,
}


def polygon(shape, points):
    mask = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return np.asarray(mask) > 0


def ellipse(shape, box):
    mask = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    return np.asarray(mask) > 0


def shift(mask, dy, dx):
    out = np.zeros_like(mask)
    ys = slice(max(dy, 0), mask.shape[0] + min(dy, 0))
    xs = slice(max(dx, 0), mask.shape[1] + min(dx, 0))
    out[ys, xs] = mask[ys.start - dy:ys.stop - dy, xs.start - dx:xs.stop - dx]
    return out


def grow(mask, radius):
    out = mask.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy <= radius * radius:
                out |= shift(mask, dy, dx)
    return out


def composite(layers, order):
    """Straight alpha over, back to front. layers values are uint8 RGBA."""
    acc_rgb = np.zeros(layers[order[0]].shape[:2] + (3,), np.float32)
    acc_a = np.zeros(layers[order[0]].shape[:2] + (1,), np.float32)
    for name in order:
        src = layers[name].astype(np.float32)
        a = src[:, :, 3:4] / 255.0
        out_a = a + acc_a * (1.0 - a)
        acc_rgb = np.where(out_a > 0, (src[:, :, :3] * a + acc_rgb * acc_a * (1.0 - a)) / np.maximum(out_a, 1e-6), 0)
        acc_a = out_a
    out = np.zeros(layers[order[0]].shape, np.uint8)
    out[:, :, :3] = np.clip(np.round(acc_rgb), 0, 255)
    out[:, :, 3] = np.clip(np.round(acc_a[:, :, 0] * 255.0), 0, 255)
    return out


def main():
    source = np.asarray(Image.open(SOURCE).convert("RGBA"))
    full = source[:, X0:X0 + WIDTH].copy()
    height, width = full.shape[:2]
    if (height, width) != (HEIGHT, WIDTH):
        raise SystemExit(f"unexpected crop {width}x{height}")
    # The export left the solid interior at alpha 252–253. Promote it so a
    # pixel in front actually hides the underpaint. The soft fringe stays.
    solid = full[:, :, 3] >= 240
    full[solid, 3] = 255
    red, green, blue, alpha = [full[:, :, i].astype(np.int16) for i in range(4)]
    luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    visible = alpha > 0
    skin = visible & (red > 165) & (green > 115) & (blue > 90) & (red > blue + 18) & (luma > 120)
    # Lining, sash, ribbons, pendant, hair clip. Dark cloth stays out.
    purple = visible & (blue > red + 8) & (blue > 85) & (luma > 65) & (blue > green - 5)
    dark = visible & ~skin & (luma < 95)

    shape = (height, width)
    # Regions are in source coordinates; shift them into the crop.
    def moved(points):
        return [(x - X0, y) for x, y in points]

    hair_region = polygon(shape, moved([
        (140, 0), (500, 0), (500, 150), (455, 200), (420, 245),
        (370, 210), (320, 200), (270, 185), (220, 165), (170, 175), (140, 140),
    ]))
    bangs = polygon(shape, moved([
        (265, 55), (415, 70), (425, 195), (370, 215), (300, 185), (255, 150),
    ]))
    arm_region = polygon(shape, moved([
        (225, 130), (315, 125), (330, 175), (315, 230), (285, 295), (230, 285), (210, 190),
    ]))
    cloth_region = polygon(shape, moved([
        (305, 215), (455, 225), (450, 345), (490, 385), (445, 400),
        (455, 530), (295, 540), (285, 400), (300, 330), (290, 245),
    ]))
    ribbon_region = polygon(shape, moved([
        (470, 330), (630, 360), (630, 790), (500, 760), (455, 520), (480, 400),
    ]))
    leg_region = polygon(shape, moved([
        (245, 450), (400, 450), (430, 700), (420, 1024), (250, 1024), (240, 700),
    ]))
    sash_band = polygon(shape, moved([
        (300, 345), (470, 345), (475, 430), (300, 430),
    ]))
    eye_boxes = ((282 - X0, 118, 308 - X0, 146), (312 - X0, 92, 342 - X0, 122))
    eye_region = np.zeros(shape, bool)
    for box in eye_boxes:
        eye_region |= ellipse(shape, box)
    mouth_box = (312, 158, 338, 176)

    labels = np.zeros(shape, np.uint8)
    names = {index + 1: name for index, name in enumerate(Z_ORDER)}
    index_of = {name: index + 1 for index, name in enumerate(Z_ORDER)}

    def claim(mask, name):
        labels[(labels == 0) & mask & visible] = index_of[name]

    # Eyes: iris, pupil and sclera inside each socket, without the surrounding skin.
    pupil = luma < 70
    sclera = (luma > 150) & (blue > 110) & (red < blue + 50)
    iris = (blue > green + 8) & (blue > 70) & (luma < 210) & (red < 210)
    claim(eye_region & (iris | sclera | pupil) & ~skin, "eyes")
    # Mouth is the short dark mark on the face, not the hair line beside it.
    claim((~skin) & visible & (luma < 100)
          & (np.arange(width)[None, :] >= mouth_box[0] - X0)
          & (np.arange(width)[None, :] <= mouth_box[2] - X0)
          & (np.arange(height)[:, None] >= mouth_box[1])
          & (np.arange(height)[:, None] <= mouth_box[3]), "mouth")

    claim(skin & arm_region & (np.arange(height)[:, None] > 135), "arm")
    # Fingers at the hip sit in front of the coat. The blob is detached from the legs.
    claim(skin & (np.arange(height)[:, None] > 490) & (np.arange(height)[:, None] < 580)
          & (np.arange(width)[None, :] > 349 - X0) & (np.arange(width)[None, :] < 390 - X0), "hand")

    claim(skin & leg_region & (np.arange(height)[:, None] > 430), "legs")
    # Boots, and the garter: a dark strap with skin on both sides.
    boots = dark & leg_region & (np.arange(height)[:, None] > 790)
    skin_near = grow(skin & (labels == index_of["legs"]), 5)
    garter = dark & skin_near & (np.arange(height)[:, None] > 470) & (np.arange(height)[:, None] < 580)
    claim(boots | garter, "legs")

    claim(visible & hair_region & bangs & ~skin, "hair_front")
    claim(visible & hair_region & ~skin & ~cloth_region, "hair_back")

    # Neck, chest and the crescent necklace ride with the torso.
    claim(skin & (np.arange(height)[:, None] > 185) & (np.arange(height)[:, None] < 430), "body")
    claim(visible & (np.arange(height)[:, None] > 185) & (np.arange(height)[:, None] < 280)
          & (np.arange(width)[None, :] > 320 - X0) & (np.arange(width)[None, :] < 430 - X0)
          & ~skin, "body")

    claim(purple & sash_band, "clothing")
    claim(visible & cloth_region & ~purple & ~ribbon_region, "clothing")
    claim(visible & ribbon_region & (purple | (np.arange(width)[None, :] > 520 - X0)), "ribbons")
    claim(skin & (np.arange(height)[:, None] <= 210), "head")
    # Whatever is still visible is the haori: sleeves, bow, lining, front panels.
    claim(visible, "coat")

    # Pull soft edge pixels that the thresholds skipped onto the nearest part.
    # claim() already took every visible pixel on the last step, so this is a guard.
    unassigned = int((visible & (labels == 0)).sum())
    if unassigned:
        raise SystemExit(f"{unassigned} visible pixels were not assigned")

    owned = {name: labels == index_of[name] for name in Z_ORDER}
    front = np.zeros(shape, bool)
    paints = {}
    for name in reversed(Z_ORDER):
        colour = np.zeros_like(full)
        colour[owned[name]] = full[owned[name]]
        radius = UNDERPAINT[name]
        # Only the solid interior. A soft fringe pixel would show the colour behind it.
        cover = front & ~owned[name] & (full[:, :, 3] == 255)
        filled = owned[name].copy()
        for _ in range(radius):
            added = np.zeros(shape, bool)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                neighbour = shift(filled, dy, dx)
                take = cover & ~filled & neighbour
                if not take.any():
                    continue
                shifted = np.roll(np.roll(colour, dy, 0), dx, 1)
                # roll wraps; the shift() test above already rejects the wrapped edge
                colour[take] = shifted[take]
                colour[take, 3] = 255
                added |= take
            filled |= added
            if not added.any():
                break
        paints[name] = colour
        front |= owned[name]

    OUT.mkdir(parents=True, exist_ok=True)
    for name in Z_ORDER:
        Image.fromarray(paints[name]).save(OUT / f"{name}.png")

    closed = np.zeros_like(full)
    draw = ImageDraw.Draw(Image.fromarray(closed))
    # Rebuilt below on a real image; ImageDraw needs the PIL image.
    lid = Image.fromarray(closed)
    pen = ImageDraw.Draw(lid)
    for box in eye_boxes:
        left, top, right, bottom = box
        pen.arc((left - 1, top + 2, right + 1, bottom + 6), 200, 340, fill=(46, 36, 58, 255), width=3)
        pen.arc((left + 1, top + 4, right - 1, bottom + 4), 205, 335, fill=(28, 22, 34, 255), width=2)
    closed = np.asarray(lid)
    Image.fromarray(closed).save(OUT / "eyes_closed.png")

    rest = composite({name: paints[name] for name in Z_ORDER}, Z_ORDER)
    # Compare against the crop. Underpaint must stay hidden.
    delta = np.abs(rest.astype(np.int16) - full.astype(np.int16))
    visible_delta = delta[visible]
    max_delta = int(visible_delta.max()) if visible_delta.size else 0
    mean_delta = float(visible_delta.mean()) if visible_delta.size else 0
    changed = int((delta.sum(axis=2) > 0).sum())

    manifest = {
        "source": "Haori Naomi, standing, transparent PNG",
        "canvas": {"width": WIDTH, "height": HEIGHT, "origin_x": X0},
        "z_order_back_to_front": Z_ORDER + ["eyes_closed"],
        "parts": {},
        "pivots": {},
        "assembly_max_channel_delta": max_delta,
        "assembly_mean_channel_delta": round(mean_delta, 4),
        "assembly_changed_pixels": changed,
    }
    for name in Z_ORDER:
        mask = owned[name]
        count = int(mask.sum())
        if count == 0:
            raise SystemExit(f"{name} is empty")
        ys, xs = np.nonzero(mask)
        manifest["parts"][name] = {
            "visible_pixels": count,
            "bounds_xyxy": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "underpaint_radius": UNDERPAINT[name],
        }
    def center(name, fy=1.0):
        ys, xs = np.nonzero(owned[name])
        return [int(xs.mean()), int(ys.min() + (ys.max() - ys.min()) * fy)]

    head_bounds = manifest["parts"]["head"]["bounds_xyxy"]
    manifest["pivots"] = {
        "head": [int((head_bounds[0] + head_bounds[2]) / 2), head_bounds[3]],
        "breath": center("clothing", 0.35),
        "coat": center("coat", 0.15),
        "ribbons": [manifest["parts"]["ribbons"]["bounds_xyxy"][0] + 20,
                    manifest["parts"]["ribbons"]["bounds_xyxy"][1] + 10],
    }
    manifest["parts"]["eyes_closed"] = {"note": "Drawn lid. Hidden while the eyes are open."}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    # Contact sheet for review: each layer on grey, then the composite and the source.
    thumb_h = 320
    scale = thumb_h / HEIGHT
    thumb_w = int(WIDTH * scale)
    sheet = Image.new("RGB", (thumb_w * (len(Z_ORDER) + 2), thumb_h + 16), (30, 30, 30))
    pen = ImageDraw.Draw(sheet)
    grey = (150, 150, 150, 255)
    for index, name in enumerate(Z_ORDER + ["rest", "source"]):
        image = rest if name == "rest" else full if name == "source" else paints[name]
        card = Image.new("RGBA", (WIDTH, HEIGHT), grey)
        card = Image.alpha_composite(card, Image.fromarray(image))
        card = card.convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.BILINEAR)
        sheet.paste(card, (index * thumb_w, 16))
        pen.text((index * thumb_w + 2, 2), name, fill=(255, 220, 120))
    sheet.save(OUT / "layers_overview.jpg", quality=85)
    Image.fromarray(rest).save(OUT / "assembly_preview.png")
    print(json.dumps({
        "changed_pixels": changed,
        "max_delta": max_delta,
        "mean_delta": round(mean_delta, 4),
        "counts": {name: manifest["parts"][name]["visible_pixels"] for name in Z_ORDER},
        "pivots": manifest["pivots"],
    }, indent=2))


if __name__ == "__main__":
    main()
