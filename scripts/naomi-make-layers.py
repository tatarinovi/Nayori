#!/usr/bin/env python3
"""Режет иллюстрацию Naomi (вариант C) на слои с прозрачным фоном для анимации.

Источник: assets/naomi/candidates/naomi-variant-c-graphic.jpg (864 × 1152).
Результат: assets/naomi/layers/*.png и layers.json (позиции слоёв в системе источника).

Слои — оригинальные пиксели рисунка, вырезанные масками по зонам и цветовым классам.
Под подвижными слоями закрашено продолжение тела, чтобы при качании не открывались дыры.
Зоны заданы в координатах просмотра 768 × 1024 (источник масштабируется в 1,125 раза).
Нужны только numpy и Pillow.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/naomi/candidates/naomi-variant-c-graphic.jpg"
OUT = ROOT / "assets/naomi/layers"
S = 1.125
# Цвет фона карточки (tokens.color.background). Тёмные тона рисунка сдвигаются к нему,
# чтобы фон иллюстрации не светлел пятнами над карточкой.
CARD = np.array([18, 18, 23], float)

im = Image.open(SRC).convert("RGB")
W, H = im.size
rgb = np.asarray(im).astype(float)
sm = np.asarray(im.filter(ImageFilter.MedianFilter(3))).astype(float)
bgc = np.median(sm[:40].reshape(-1, 3), axis=0)


def poly(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in pts], fill=255)
    return np.asarray(m) > 0


def box(b):
    x0, y0, x1, y1 = b
    return poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])


def dil(m, r):
    return np.asarray(Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.MaxFilter(2 * r + 1))) > 0


def ero(m, r):
    return np.asarray(Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.MinFilter(2 * r + 1))) > 0


def fill_holes(m):
    """Закрашивает области, не связанные с краем кадра (обход фона заливкой)."""
    h, w = m.shape
    seen = m.copy()
    stack = [(0, 0)]
    seen[0, 0] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    background = seen & ~m
    return ~background


def nearest_fill(img, valid, target, maxit):
    """Закрашивает пиксели target цветом ближайших valid, не дальше maxit шагов."""
    img = img.copy()
    valid = valid.copy()
    todo = target & ~valid
    for _ in range(maxit):
        if not todo.any():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(valid.shape, int)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                sv = np.roll(np.roll(valid, dy, 0), dx, 1)
                sc = np.roll(np.roll(img, dy, 0), dx, 1)
                acc += sc * sv[..., None]
                cnt += sv
        new = todo & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        valid |= new
        todo &= ~new
    return img, valid


# --- зоны (координаты просмотра 768 × 1024) ---
HEAD = [(280, 60), (440, 60), (470, 130), (485, 175), (482, 235), (455, 260), (395, 268), (340, 264), (305, 246), (292, 205), (285, 160), (272, 110)]
HL = [(175, 175), (298, 158), (335, 235), (350, 262), (352, 300), (350, 440), (250, 470), (175, 445), (175, 300)]
HR = [(430, 205), (470, 150), (505, 170), (545, 260), (540, 335), (522, 445), (405, 445), (405, 262)]
SCARF = [(405, 245), (450, 245), (480, 300), (530, 345), (600, 362), (645, 405), (662, 456), (600, 456), (582, 500), (555, 500), (556, 440), (540, 405), (500, 395), (470, 370), (440, 330), (410, 300)]
EARL = [(294, 72), (318, 88), (342, 112), (350, 132), (348, 152), (318, 148), (304, 120)]
EARR = [(402, 50), (420, 100), (430, 128), (420, 136), (395, 134), (374, 118), (384, 92)]
EARL_PIVOT = (333, 138)
EARR_PIVOT = (398, 118)
# Веки: многоугольники в пикселях источника; закрашиваются кожей поверх открытых глаз.
LIDL = [(390, 205), (402, 202), (413, 208), (412, 214), (404, 218), (396, 217), (390, 212)]
LIDR = [(429, 195), (440, 191), (452, 193), (459, 198), (456, 206), (446, 209), (436, 207), (429, 202)]
PINC = (398, 152, 428, 212)
MOONBOX = (60, 20, 280, 230)  # зона большой луны: она убирается из рисунка целиком
MOON_SEED = (130, 100)
SHOES = [(325, 872, 385, 968), (460, 872, 530, 968)]
WAIST = 366  # граница верха и низа тела

# --- маска персонажа ---
M0 = np.abs(sm - bgc).max(2) > 8
shoebox = np.zeros((H, W), bool)
for b in SHOES:
    shoebox |= box(b)
Mc = fill_holes(ero(dil(M0, 3), 2))
def hull_mask(mask):
    """Выпуклая оболочка точек mask: туфли тёмные, как и фон, их контур замкнут целиком."""
    pts = sorted(set(map(tuple, np.argwhere(mask)[:, ::-1].tolist())))
    if len(pts) < 3:
        return np.zeros_like(mask)
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for pt in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], pt) <= 0:
            lower.pop()
        lower.append(pt)
    for pt in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], pt) <= 0:
            upper.pop()
        upper.append(pt)
    hull = lower[:-1] + upper[:-1]
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(hull, fill=255)
    return np.asarray(m) > 0


for b in SHOES:
    Mc |= hull_mask(box(b) & M0 & ero(dil(M0, 2), 1))
Mc = fill_holes(Mc)
def component(mask, seed):
    """Связная область mask, содержащая seed (координаты просмотра)."""
    h, w = mask.shape
    sx, sy = int(seed[0] * S), int(seed[1] * S)
    seen = np.zeros_like(mask)
    stack = [(sy, sx)]
    seen[sy, sx] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    return seen


# Большая луна — отдельная от персонажа фигура: вырезается вместе с ореолом и в слои не попадает.
moon_only = component(Mc & box(MOONBOX), MOON_SEED)
moon_halo = dil(moon_only, 6)
chars = Mc & ~moon_halo
# Края на чужом фоне: цвет пограничных пикселей берётся у ближайшей внутренней области,
# иначе на светлых обоях виден тёмный ободок из смеси цвета фона и рисунка.
interior = ero(chars, 3)
edge_band = chars & ~interior
rgb, _ = nearest_fill(rgb, interior, edge_band, 6)
print("луна убрана:", int(moon_only.sum()), "пикселей; касается персонажа:", bool((dil(moon_only, 3) & Mc & ~moon_only & ~moon_halo).any()))

# --- цветовые классы: k-means по пикселям персонажа ---
rng = np.random.default_rng(2)
pix = sm[chars]
samp = pix[rng.choice(len(pix), min(80000, len(pix)), replace=False)]
K = 14
cent = samp[rng.choice(len(samp), K, replace=False)]
for _ in range(40):
    lab_s = ((samp[:, None, :] - cent[None]) ** 2).sum(2).argmin(1)
    for i in range(K):
        if (lab_s == i).any():
            cent[i] = samp[lab_s == i].mean(0)
flat = sm.reshape(-1, 3)
lab = np.empty(len(flat), np.int16)
for i in range(0, len(flat), 100000):
    lab[i:i + 100000] = ((flat[i:i + 100000, None, :] - cent[None]) ** 2).sum(2).argmin(1)
lab = lab.reshape(H, W)


def klass(pred):
    return np.isin(lab, [i for i in range(K) if pred(cent[i])])


lum = lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
is_skin = klass(lambda c: lum(c) > 165 and c[0] - c[1] < 28)
is_pink = (sm[..., 0] - sm[..., 1] > 30) & (sm[..., 0] > 110)
is_gray = klass(lambda c: 40 < lum(c) < 85 and abs(c[2] - c[0]) < 20 and abs(c[1] - c[0]) < 12)
is_hairish = chars & ~is_skin & ~is_pink & ~is_gray

yy, xx = np.mgrid[0:H, 0:W]
yv = yy / S
xv = xx / S

# --- слои ---
layers = {}  # name -> (mask, pixel image or None)

# уши
earL = poly(EARL) & chars
earR = poly(EARR) & chars
# подвеска заколки
dangle = dil(box(PINC) & chars & is_pink, 1) & chars & ~is_skin
dangle &= yv > 158
# шарф
pinkc = is_pink & poly(SCARF) & chars & (yv > 250)
scarf = fill_holes(ero(dil(pinkc, 4), 3)) & poly(SCARF) & chars & (yv > 250)
# волосы
hl = poly(HL) & chars & ~is_skin & ~is_pink & ~is_gray & (yv > 185)
hr = poly(HR) & chars & ~is_skin & ~is_pink & ~is_gray & (yv > 185) & ~scarf
hl_y = [(150, 322), (308, 392), (378, 480)]
hr_y = [(150, 340), (326, 480)]
scarf_x = [(0, 508), (492, 604), (588, 900)]
parts = {}
parts["ear_left"] = earL
parts["ear_right"] = earR
parts["pin_dangle"] = dangle
# повязка шарфа на шее и розовый полумесяц заколки: перекрашиваются, как и хвост шарфа
neck_band = dil(poly(HEAD) & chars & is_pink & (yv >= 222) & (xv > 330), 1) & chars
pin_moon = dil(box((393, 120, 432, 154)) & chars & is_pink, 1) & chars
parts["scarf_neck"] = neck_band
parts["pin_moon"] = pin_moon
for i, (a, b) in enumerate(hl_y):
    parts[f"hair_left_{i + 1}"] = hl & (yv >= a) & (yv < b)
for i, (a, b) in enumerate(hr_y):
    parts[f"hair_right_{i + 1}"] = hr & (yv >= a) & (yv < b)
for i, (a, b) in enumerate(scarf_x):
    parts[f"scarf_{i + 1}"] = scarf & (xv >= a) & (xv < b)

# тело под подвижным: пиксели подвижных слоёв заменяются продолжением ближайшего цвета
moving = np.zeros((H, W), bool)
for k, m in parts.items():
    if k.startswith("hair_") or k in ("scarf_1", "scarf_2", "scarf_3"):
        moving |= m
body_support = chars & ~moving
body_rgb, _ = nearest_fill(rgb, body_support, moving, 28)
body_valid = body_support | (moving & dil(body_support, 28))
head_zone = poly(HEAD)
head_top = head_zone & (yv < 232)
# голова: лицо, чёлка, прядки у лица, уши (нижняя часть), заколка, шея и повязка шарфа
head = head_zone & chars & ~(earL & (yv < EARL_PIVOT[1] - 4)) & ~(earR & (yv < EARR_PIVOT[1] - 4))
head_rgb = rgb.copy()
# глаза и подвеска стираются из головы: закрашиваются кожей и волосами рядом
erase = dil(dangle, 1) | neck_band | pin_moon
head_rgb, _ = nearest_fill(head_rgb, head & ~erase, erase & head, 14)
# веки: плоская кожа лица
def lid_mask(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m) > 0
lid_l = lid_mask(LIDL)
lid_r = lid_mask(LIDR)
skin_med = np.median(rgb[is_skin & head & (yv > 160) & (yv < 230)], axis=0)
lid_rgb = rgb.copy()
lid_rgb[lid_l | lid_r] = skin_med
parts["lid_left"] = lid_l
parts["lid_right"] = lid_r
# уши: волосы и кожа на месте ушей над линией крепления убираются из головы выше
body = chars & ~head_top & body_valid
body_hole = body & moving
torso = body & (yv < WAIST + 8)
lower = body & (yv >= WAIST - 6)

draw = {}
draw["body_lower"] = (lower, body_rgb)
draw["body_torso"] = (torso, body_rgb)
for k in parts:
    if k.startswith("hair_") or k.startswith("scarf_"):
        draw[k] = (parts[k], rgb)
draw["head"] = (head, head_rgb)
for k in ("scarf_neck", "pin_moon", "ear_left", "ear_right", "pin_dangle"):
    draw[k] = (parts[k], rgb)
draw["lid_left"] = (lid_l, lid_rgb)
draw["lid_right"] = (lid_r, lid_rgb)


def neutralize(col):
    """Тёмные тона рисунка сдвигаются к цвету карточки."""
    l = (0.3 * col[..., 0] + 0.59 * col[..., 1] + 0.11 * col[..., 2])
    f = np.clip((95 - l) / 50, 0, 1)[..., None]
    return np.clip(col + (CARD - bgc) * f, 0, 255)


def export(name, mask, colors, order, pad=3):
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        print("пустой слой", name)
        return None
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, W)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, H)
    m = mask[y0:y1, x0:x1]
    col = colors[y0:y1, x0:x1]
    ext, valid = nearest_fill(col, m, dil(m, pad), pad + 1)
    alpha = np.asarray(Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.7)))
    if name in ("pin_moon", "pin_dangle") or name.startswith("scarf_"):
        # Яркостная маска: основной цвет слоя становится белым, узор остаётся темнее.
        # В QML её красит MultiEffect.colorization цветом из токенов.
        l = 0.3 * ext[..., 0] + 0.59 * ext[..., 1] + 0.11 * ext[..., 2]
        ref = np.median(l[m]) if m.any() else 1.0
        v = np.clip(l / ref, 0, 1)
        v = 0.7 + 0.3 * v  # узор остаётся различимым, но не серит цвет
        v = v * 255
        out = np.dstack([v, v, v, alpha]).astype("uint8")
    else:
        out = np.dstack([neutralize(ext), alpha]).astype("uint8")
    Image.fromarray(out, "RGBA").save(OUT / f"{name}.png", optimize=True)
    return {"name": name, "file": f"{name}.png", "x": int(x0), "y": int(y0), "w": int(x1 - x0), "h": int(y1 - y0), "z": order}


# --- варианты эмоций: рисуются векторно, видны только при поглаживании ---
EMO_SS = 8  # во сколько раз рисуем крупнее ради сглаживания
LASH = (20, 17, 28)  # цвет ресниц: тёмный тон волос, как у нарисованных глаз
SMILE = (126, 92, 112)  # мягкий тёмно-розовый для линии рта
# (центр, ширина, наклон в градусах, подъём дуги) — по открытым глазам рисунка
EYE_HAPPY = {
    "eye_happy_left": ((400.5, 212.0), 24.0, 4.0, 6.5),
    "eye_happy_right": ((445.0, 199.5), 30.0, -15.0, 7.5),
}
MOUTH = (427.5, 234.2)  # центр нарисованного рта (закрыт, едва заметен)
BLUSH = {
    "blush_left": ((410.0, 227.5), 27.0, 14.0, -4.0),
    "blush_right": ((442.5, 216.5), 24.0, 12.5, -14.0),
}


def bezier(p0, p1, p2, n=48):
    t = np.linspace(0, 1, n)[:, None]
    return (1 - t) ** 2 * np.array(p0) + 2 * (1 - t) * t * np.array(p1) + t ** 2 * np.array(p2)


def ribbon(points, width_mid, width_end, ss):
    """Полоса переменной толщины вдоль ломаной: тонкая на концах, толстая посередине."""
    pts = np.asarray(points, float)
    d = np.gradient(pts, axis=0)
    d /= np.linalg.norm(d, axis=1)[:, None] + 1e-9
    nrm = np.stack([-d[:, 1], d[:, 0]], 1)
    t = np.linspace(0, 1, len(pts))
    w = (width_end + (width_mid - width_end) * np.sin(np.pi * t) ** 0.7)[:, None] / 2
    left = pts + nrm * w
    right = pts - nrm * w
    return [tuple(p * ss) for p in np.vstack([left, right[::-1]])]


def rotate(point, center, degrees):
    a = np.radians(degrees)
    c, s_ = np.cos(a), np.sin(a)
    x, y = point[0] - center[0], point[1] - center[1]
    return (center[0] + x * c - y * s_, center[1] + x * s_ + y * c)


def emotion_layer(name, box_, painter):
    """Рисует слой в рамке box_ = (x0, y0, x1, y1) в пикселях источника и сохраняет его."""
    x0, y0, x1, y1 = box_
    w, h = x1 - x0, y1 - y0
    img = Image.new("RGBA", (w * EMO_SS, h * EMO_SS), (0, 0, 0, 0))
    painter(ImageDraw.Draw(img), lambda p: ((p[0] - x0) * EMO_SS, (p[1] - y0) * EMO_SS), img)
    img = img.resize((w, h), Image.LANCZOS)
    img.save(OUT / f"{name}.png", optimize=True)
    return {"name": name, "file": f"{name}.png", "x": x0, "y": y0, "w": w, "h": h}


def happy_eye(center, width, tilt, rise):
    half = width / 2
    p0 = (center[0] - half, center[1] + rise * 0.15)
    p2 = (center[0] + half, center[1] + rise * 0.15)
    p1 = (center[0], center[1] - rise * 1.55)
    pts = [rotate(p, center, tilt) for p in bezier(p0, p1, p2)]
    # короткая ресница-«хвостик» на внешнем конце дуги (наружу и вниз)
    return pts


def build_emotions():
    skin = tuple(int(v) for v in skin_med)
    meta = []

    def eye(centre, width, tilt, rise, outer_left):
        def paint(d, to, img):
            pts = happy_eye(centre, width, tilt, rise)
            d.polygon([(p[0], p[1]) for p in ribbon([to(p) for p in pts], 3.4 * EMO_SS, 0.5 * EMO_SS, 1)], fill=LASH + (255,))
            tip = pts[0] if outer_left else pts[-1]
            sign = -1 if outer_left else 1
            tick = [(tip[0], tip[1]), (tip[0] + sign * 2.2, tip[1] + 1.6), (tip[0] + sign * 3.6, tip[1] + 3.8)]
            d.polygon([(p[0], p[1]) for p in ribbon([to(p) for p in bezier(tick[0], tick[1], tick[2], 12)], 1.7 * EMO_SS, 0.3 * EMO_SS, 1)], fill=LASH + (255,))
        return paint

    for name, (centre, width, tilt, rise) in EYE_HAPPY.items():
        pad = 9
        box_ = (int(centre[0] - width / 2 - pad), int(centre[1] - rise - pad), int(centre[0] + width / 2 + pad), int(centre[1] + rise + pad))
        meta.append(emotion_layer(name, box_, eye(centre, width, tilt, rise, name.endswith("left"))))

    # улыбка: кожа закрывает нарисованный закрытый рот, поверх — мягкая дуга с приподнятыми уголками
    def mouth(d, to, img):
        cx, cy = MOUTH
        patch = Image.new("L", img.size, 0)
        ImageDraw.Draw(patch).ellipse([*to((cx - 6.5, cy - 2.8)), *to((cx + 6.5, cy + 2.8))], fill=255)
        patch = patch.filter(ImageFilter.GaussianBlur(1.0 * EMO_SS))
        img.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", img.size, skin).split(), patch)))
        pts = bezier((cx - 4.6, cy - 0.7), (cx + 0.2, cy + 3.2), (cx + 5.0, cy - 1.5))
        d.polygon([(p[0], p[1]) for p in ribbon([to(p) for p in pts], 1.5 * EMO_SS, 0.3 * EMO_SS, 1)], fill=SMILE + (255,))
    meta.append(emotion_layer("mouth_smile", (int(MOUTH[0]) - 12, int(MOUTH[1]) - 8, int(MOUTH[0]) + 12, int(MOUTH[1]) + 9), mouth))

    # румянец: белая яркостная маска с мягким краем; в QML её красит цвет secondary
    for name, (centre, bw, bh, tilt) in BLUSH.items():
        def blush(d, to, img, centre=centre, bw=bw, bh=bh, tilt=tilt):
            mask = Image.new("L", img.size, 0)
            ImageDraw.Draw(mask).ellipse([*to((centre[0] - bw / 2, centre[1] - bh / 2)), *to((centre[0] + bw / 2, centre[1] + bh / 2))], fill=255)
            mask = mask.rotate(-tilt, center=to(centre), resample=Image.BICUBIC)
            mask = mask.filter(ImageFilter.GaussianBlur(bh * 0.28 * EMO_SS))
            arr = np.asarray(mask).astype(float) * 0.62
            out = np.dstack([np.full(arr.shape, 255.0)] * 3 + [arr]).astype("uint8")
            img.alpha_composite(Image.fromarray(out, "RGBA"))
        r = int(max(bw, bh) / 2 + 9)
        meta.append(emotion_layer(name, (int(centre[0]) - r, int(centre[1]) - r, int(centre[0]) + r, int(centre[1]) + r), blush))
    return meta


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    order_list = ["body_lower", "body_torso"] + [k for k in draw if k.startswith("hair_")] + [k for k in draw if k.startswith("scarf_")] + ["head", "scarf_neck", "pin_moon", "ear_left", "ear_right", "pin_dangle", "lid_left", "lid_right"]
    meta = []
    for z, name in enumerate(order_list):
        mask, colors = draw[name]
        info = export(name, mask, colors, z)
        if info:
            meta.append(info)
    base_z = len(meta)
    for z, info in enumerate(build_emotions()):
        info["z"] = base_z + z
        meta.append(info)
    pivots = {
        "ear_left": [round(EARL_PIVOT[0] * S), round(EARL_PIVOT[1] * S)],
        "ear_right": [round(EARR_PIVOT[0] * S), round(EARR_PIVOT[1] * S)],
    }
    (OUT / "layers.json").write_text(json.dumps({"width": W, "height": H, "layers": meta, "pivots": pivots}, indent=1, ensure_ascii=False))
    # манифест для QML: поля x, y, w, h — в системе источника 864 × 1152
    table = {m["name"]: {k: m[k] for k in ("file", "x", "y", "w", "h")} for m in meta}
    js = "// Создано scripts/naomi-make-layers.py. Не править вручную.\n.pragma library\n"
    js += f"var width = {W};\nvar height = {H};\n"
    js += "var layers = " + json.dumps(table, indent=1) + ";\n"
    (ROOT / "surfaces/companion/NaomiLayers.js").write_text(js)
    # контрольная сборка в покое поверх фона карточки
    comp = Image.new("RGBA", (W, H), tuple(int(v) for v in CARD) + (255,))
    for info in meta:
        l = Image.open(OUT / info["file"])
        comp.alpha_composite(l, (info["x"], info["y"]))
    preview = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if preview:
        comp.convert("RGB").save(preview)
    print("слоёв:", len(meta))


if __name__ == "__main__":
    main()
