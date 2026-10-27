#!/usr/bin/env python3
"""Place expression details from the sheet onto the haori face.

The sheet is a new drawing of the bust. Kept pieces are the closed eyes, the
open mouth, a small blush from the laugh, and the sleepy eyes. They are scaled
so the two irises land on the irises of the standing sprite. Everything else
stays the original painting. Results are 470x1024 and share its origin.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SHEET = ROOT / "assets/naomi/haori/expressions-sheet.png"
OUT = ROOT / "assets/naomi/haori"
CANVAS = (470, 1024)

# Cells inside the sheet chrome, in labelled order.
CELLS = {
    "neutral": (8, 8, 196, 228),
    "blink": (212, 8, 400, 228),
    "laugh": (622, 8, 810, 228),
    "talk": (8, 280, 196, 500),
    "sleepy": (622, 280, 810, 500),
}
# A one-pixel nudge puts each expression on the neutral cell before scaling.
NUDGE = {"blink": (-1, 0), "talk": (0, -1), "sleepy": (0, -1)}
# Small blush on the visible cheek, under the hair and the hand. Radii in canvas pixels.
CHEEKS = ((156, 140, 8, 5), (180, 122, 9, 5))
# canvas = SCALE * sheet_cell + (TX, TY). Fitted on the two irises.
SCALE, TX, TY = 1.764, 17.88, 13.31


def nudge(image, dx, dy):
    shifted = np.zeros_like(image)
    height, width = image.shape[:2]
    x0, x1 = max(0, dx), min(width, width + dx)
    y0, y1 = max(0, dy), min(height, height + dy)
    shifted[y0:y1, x0:x1] = image[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return shifted


def warp(image):
    inverse = 1 / SCALE
    affine = (inverse, 0, -TX * inverse, 0, inverse, -TY * inverse)
    straight = image.astype(np.float32)
    alpha = straight[:, :, 3:4] / 255
    straight[:, :, :3] *= alpha
    planes = []
    for channel in range(4):
        source = Image.fromarray(np.clip(straight[:, :, channel], 0, 255).astype(np.uint8))
        planes.append(np.array(source.transform(CANVAS, Image.AFFINE, affine, resample=Image.Resampling.BILINEAR)))
    warped = np.stack(planes, axis=-1).astype(np.float32)
    coverage = warped[:, :, 3:4] / 255
    color = np.zeros_like(warped[:, :, :3])
    np.divide(warped[:, :, :3], np.maximum(coverage, 1e-4), out=color, where=coverage > 1e-3)
    result = np.zeros((CANVAS[1], CANVAS[0], 4), np.float32)
    result[:, :, :3] = np.clip(color, 0, 255)
    result[:, :, 3] = warped[:, :, 3]
    return result


def dilate(mask, radius):
    image = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.array(image.filter(ImageFilter.MaxFilter(radius * 2 + 1))) > 0


def soften(mask, radius):
    image = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.array(image.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255


def layer(color, alpha):
    painted = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
    painted[:, :, :3] = np.clip(color[:, :, :3], 0, 255).astype(np.uint8)
    painted[:, :, 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    return painted


def sleepy_alpha(eye_pixels, sleepy, hair):
    """A smooth patch over each open eye.

    A mask built from changed pixels left a straight cut across the upper lid
    and a tail down the cheek. An ellipse around each eye keeps the whole lid.
    The ellipse also crosses the hair strand beside the cheek. That strand
    stays uncovered, including the part that was saved into the eyes cut.
    """
    height, width = eye_pixels.shape
    yy, xx = np.ogrid[:height, :width]
    alpha = np.zeros((height, width), np.float32)
    for x0, x1 in ((0, 162), (162, width)):
        region = eye_pixels.copy()
        region[:, :x0] = False
        region[:, x1:] = False
        ys, xs = np.nonzero(region)
        if ys.size == 0:
            continue
        cx = float(xs.mean())
        cy = float(ys.mean()) - 2
        rx = (int(xs.max()) - int(xs.min())) / 2 + 6
        ry = (int(ys.max()) - int(ys.min())) / 2 + 8
        falloff = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        alpha = np.maximum(alpha, np.clip(1 - falloff, 0, 1) ** 1.2)
    on_hair = hair[:, :, 3] > 40
    alpha[eye_pixels & ~on_hair] = 1
    alpha[on_hair] = 0
    covered = sleepy[:, :, 3] / 255
    alpha *= covered
    alpha[eye_pixels & (sleepy[:, :, 3] > 80) & ~on_hair] = 1
    return alpha


def blush_color(laugh):
    """Pink of the laugh cheeks, not the open mouth."""
    samples = []
    for x0, y0, x1, y1 in ((56, 66, 74, 80), (104, 68, 122, 82)):
        patch = laugh[y0:y1, x0:x1]
        red, green, blue, alpha = [patch[:, :, i] for i in range(4)]
        pink = red.astype(np.int16) - green.astype(np.int16)
        mask = (alpha > 180) & (red > 190) & (green > 120) & (blue > 100) & (pink > 50)
        if mask.any():
            samples.append(patch[mask][:, :3])
    return np.median(np.concatenate(samples), 0)


def blush_layer(color, head, arm, hair):
    height, width = CANVAS[1], CANVAS[0]
    yy, xx = np.ogrid[:height, :width]
    alpha = np.zeros((height, width), np.float32)
    for cx, cy, rx, ry in CHEEKS:
        falloff = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        alpha = np.maximum(alpha, np.clip(1 - falloff, 0, 1) ** 1.7)
    alpha *= 0.62
    alpha *= (head[:, :, 3] > 80) & (arm[:, :, 3] < 40) & (hair[:, :, 3] < 40)
    painted = np.zeros((height, width, 4), np.float32)
    painted[:, :, :3] = color
    painted[:, :, 3] = alpha * 255
    return painted


def mouth_change(talk, neutral, mouth):
    difference = np.abs(talk.astype(np.int16) - neutral.astype(np.int16)).sum(axis=2)
    changed = (difference > 90) & (talk[:, :, 3] > 100)
    seed = dilate(mouth[:, :, 3] > 20, 2) & changed
    keep = np.zeros(changed.shape, np.bool_)
    stack = list(zip(*np.nonzero(seed)))
    while stack:
        y, x = stack.pop()
        if keep[y, x] or not changed[y, x]:
            continue
        keep[y, x] = True
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if 0 <= ny < keep.shape[0] and 0 <= nx < keep.shape[1] and not keep[ny, nx]:
                    stack.append((ny, nx))
    return keep & dilate(mouth[:, :, 3] > 10, 14)


def main():
    sheet = np.array(Image.open(SHEET).convert("RGBA"))
    cells = {}
    for name, (x0, y0, x1, y1) in CELLS.items():
        cells[name] = sheet[y0:y1, x0:x1]
    for name, (dx, dy) in NUDGE.items():
        cells[name] = nudge(cells[name], dx, dy)
    warped = {name: warp(image) for name, image in cells.items()}

    eyes = np.array(Image.open(OUT / "eyes.png"))
    head = np.array(Image.open(OUT / "head.png"))
    arm = np.array(Image.open(OUT / "arm.png"))
    hair = np.array(Image.open(OUT / "hair_front.png"))
    hair_back = np.array(Image.open(OUT / "hair_back.png"))
    mouth = np.array(Image.open(OUT / "mouth.png"))
    hand = arm[:, :, 3] > 100
    eye_pixels = eyes[:, :, 3] > 30
    eye_mask = dilate(eye_pixels, 5) & (dilate(head[:, :, 3] > 80, 4) | dilate(eye_pixels, 1))
    eye_mask &= ~hand
    eye_alpha = soften(eye_mask, 1.3)

    mouth_mask = dilate(mouth_change(warped["talk"], warped["neutral"], mouth), 2)
    mouth_mask |= dilate(mouth[:, :, 3] > 20, 2)
    mouth_mask &= ~hand
    mouth_alpha = soften(mouth_mask, 1.1) * (warped["talk"][:, :, 3] / 255)

    blink_alpha = eye_alpha * (warped["blink"][:, :, 3] / 255)
    strand = hair.copy()
    strand[:, :, 3] = np.maximum(hair[:, :, 3], hair_back[:, :, 3])
    sleepy_cover = sleepy_alpha(eye_pixels, warped["sleepy"], strand)
    color = blush_color(cells["laugh"])
    blush = blush_layer(color, head, arm, hair)
    Image.fromarray(layer(warped["blink"], blink_alpha)).save(OUT / "face_blink.png")
    Image.fromarray(layer(warped["talk"], mouth_alpha)).save(OUT / "face_talk.png")
    Image.fromarray(layer(warped["sleepy"], sleepy_cover)).save(OUT / "face_sleepy.png")
    Image.fromarray(np.clip(blush, 0, 255).astype(np.uint8)).save(OUT / "face_blush.png")
    print(
        f"face_blink {int((blink_alpha > 0.2).sum())} px, "
        f"face_talk {int((mouth_alpha > 0.2).sum())} px, "
        f"face_sleepy {int((sleepy_cover > 0.2).sum())} px, "
        f"face_blush {int((blush[:, :, 3] > 25).sum())} px, color {np.round(color).astype(int).tolist()}"
    )


if __name__ == "__main__":
    main()
