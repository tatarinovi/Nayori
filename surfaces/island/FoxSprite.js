// Pixel renderer for the island fox. Pure function: pose in, 52x30 palette ids out.
// Shapes are rasterised by pixel centres, so the result is crisp at 1x and
// deterministic for tests. Palette ids are mapped to tokens by Fox.qml.
var W = 52, H = 30
// Palette ids.
var EMPTY = 0, BODY = 1, LIGHT = 2, DARK = 3, SHADE = 4, TAIL = 5, TAIL_TIP = 6, EYE = 7

function lerp(a, b, t) { return a + (b - a) * t }
function lerpPt(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t)] }

// The shapes are drawn on a grid with MARGIN spare cells on every side, then cropped to
// W x H, so measure() can tell what the crop would cut off.
var MARGIN = 12, BW = W + 2 * MARGIN, BH = H + 2 * MARGIN
function draw(pose) {
    var buf = new Array(BW * BH)
    for (var i = 0; i < BW * BH; i++) buf[i] = EMPTY
    var rest = pose.rest === undefined ? 1 : pose.rest
    var up = 1 - rest                       // 0 lying, 1 on paws
    var walk = (pose.walk || 0) * up
    var stride = pose.stride || 0
    var breath = pose.breath || 0
    var look = pose.head || 0
    var px = pose.x || 0, py = pose.y || 0

    function polyInside(pts, x, y) {
        var inside = false
        for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
            var a = pts[i], b = pts[j]
            if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside
        }
        return inside
    }
    function segDist(x, y, ax, ay, bx, by) {
        var dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy
        var t = l2 > 0 ? Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / l2)) : 0
        var ex = ax + dx * t - x, ey = ay + dy * t - y
        return Math.sqrt(ex * ex + ey * ey)
    }
    // Shape = bounding box + predicate(x, y, pad).
    function poly(pts) {
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
        pts.forEach(function (p) { x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]); y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]) })
        return { x0: x0, y0: y0, x1: x1, y1: y1, has: function (x, y, pad) {
            if (polyInside(pts, x, y)) return true
            if (!pad) return false
            for (var i = 0, j = pts.length - 1; i < pts.length; j = i++)
                if (segDist(x, y, pts[i][0], pts[i][1], pts[j][0], pts[j][1]) <= pad) return true
            return false
        } }
    }
    // Chain of round "capsules"; every point is [x, y, radius].
    function chain(pts) {
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
        pts.forEach(function (p) { x0 = Math.min(x0, p[0] - p[2]); x1 = Math.max(x1, p[0] + p[2]); y0 = Math.min(y0, p[1] - p[2]); y1 = Math.max(y1, p[1] + p[2]) })
        return { x0: x0, y0: y0, x1: x1, y1: y1, has: function (x, y, pad) {
            for (var i = 0; i < pts.length; i++) {
                var a = pts[i], b = pts[Math.min(i + 1, pts.length - 1)]
                var dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy
                var t = l2 > 0 ? Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / l2)) : 0
                var ex = a[0] + dx * t - x, ey = a[1] + dy * t - y
                if (Math.sqrt(ex * ex + ey * ey) <= lerp(a[2], b[2], t) + (pad || 0)) return true
            }
            return false
        } }
    }
    // gap: ids that are cut away (one pixel around the shape) before painting.
    function paint(shape, color, gap, over) {
        var pad = gap ? 1 : 0
        var xa = Math.max(-MARGIN, Math.floor(shape.x0 - pad)), xb = Math.min(W + MARGIN - 1, Math.ceil(shape.x1 + pad))
        var ya = Math.max(-MARGIN, Math.floor(shape.y0 - pad)), yb = Math.min(H + MARGIN - 1, Math.ceil(shape.y1 + pad))
        for (var y = ya; y <= yb; y++) for (var x = xa; x <= xb; x++) {
            var cx = x + 0.5, cy = y + 0.5, at = (y + MARGIN) * BW + x + MARGIN
            if (gap && gap.indexOf(buf[at]) >= 0 && shape.has(cx, cy, pad)) buf[at] = EMPTY
            if (shape.has(cx, cy, 0) && (!over || over.indexOf(buf[at]) >= 0)) buf[at] = color
        }
    }
    // Clears ids within one pixel of the shapes without painting them.
    function cut(shapes, ids) {
        shapes.forEach(function (shape) {
            var xa = Math.max(-MARGIN, Math.floor(shape.x0 - 1)), xb = Math.min(W + MARGIN - 1, Math.ceil(shape.x1 + 1))
            var ya = Math.max(-MARGIN, Math.floor(shape.y0 - 1)), yb = Math.min(H + MARGIN - 1, Math.ceil(shape.y1 + 1))
            for (var y = ya; y <= yb; y++) for (var x = xa; x <= xb; x++)
                if (ids.indexOf(buf[(y + MARGIN) * BW + x + MARGIN]) >= 0 && shape.has(x + 0.5, y + 0.5, 1)) buf[(y + MARGIN) * BW + x + MARGIN] = EMPTY
        })
    }
    function mixPts(lying, standing) { return lying.map(function (p, i) { return lerpPt(p, standing[i], up) }) }

    // --- Torso: rump, back, shoulder, chest, tucked belly. -----------------------------
    var lift = breath * 0.8
    var torsoLying = [[12, 30], [10, 24], [14, 18.5], [21, 16.5], [29, 18], [35, 23], [35, 30], [26, 30], [18, 30]]
    var torsoStanding = [[14.5, 22.5], [13, 18], [16.5, 14], [24, 12.5], [32, 11], [37.5, 14], [36.5, 21.5], [25, 20], [18.5, 21.8]]
    var torso = mixPts(torsoLying, torsoStanding)
    torso[2][1] -= lift * 0.5; torso[3][1] -= lift; torso[4][1] -= lift * 0.7
    var torsoShape = poly(torso)

    // --- Legs: hip, joint, foot. Diagonal pairs in antiphase. ----------------------------
    function leg(lyingHip, lyingFoot, hipX, phase, bendX, color, sockColor, hipR) {
        var swing = Math.sin(phase) * 3.4 * walk
        var liftY = Math.max(0, Math.cos(phase)) * 2.6 * walk
        var hip = lerpPt(lyingHip, [hipX, 17], up)
        var foot = lerpPt(lyingFoot, [hipX + swing, 28.2 - liftY], up)
        var jnt = [lerp(hip[0], foot[0], 0.5) + bendX * up, lerp(hip[1], foot[1], 0.5) - lift * 0]
        var pts = [[hip[0], hip[1], hipR], [jnt[0], jnt[1], 1.6], [foot[0], foot[1], 1.5]]
        var sock = [[lerp(jnt[0], foot[0], 0.55), lerp(jnt[1], foot[1], 0.55), 1.5], [foot[0], foot[1], 1.5]]
        return { body: chain(pts), sock: chain(sock), color: color, sockColor: sockColor }
    }
    var farHind = leg([16, 26], [23, 28.2], 21, stride + Math.PI, -3, SHADE, DARK, 2.8)
    var farFront = leg([32, 25], [50.2, 28.2], 30, stride, 0.8, SHADE, DARK, 2.2)
    var nearHind = leg([14.5, 25.5], [21, 28.2], 16.5, stride, -3, BODY, DARK, 2.8)
    var nearFront = leg([34, 25], [48.2, 28.2], 36, stride + Math.PI, 0.8, BODY, DARK, 2.2)
    function drawLeg(l, gap) { paint(l.body, l.color, gap); paint(l.sock, l.sockColor) }
    drawLeg(farHind); drawLeg(farFront)

    // --- Tail: one big bucket with an S curve, light tip. -------------------------------
    var sway = (pose.tail || 0) * 0.04
    function rot(p, o) {
        var c = Math.cos(sway), s = Math.sin(sway), dx = p[0] - o[0], dy = p[1] - o[1]
        return [o[0] + dx * c - dy * s, o[1] + dx * s + dy * c]
    }
    var base = lerpPt([12.5, 27], [14.5, 19], up)
    var p1 = rot(lerpPt([6, 28.2], [6.5, 22], up), base)
    var p2 = rot(lerpPt([4.8, 19.5], [6.5, 10], up), base)
    var p3 = rot(lerpPt([8, 14.5], [9.5, 5.2], up), base)
    var tailPts = [], tipPts = []
    var N = 16
    for (var n = 0; n <= N; n++) {
        var u = n / N, v = 1 - u
        var bx = v * v * v * base[0] + 3 * v * v * u * p1[0] + 3 * v * u * u * p2[0] + u * u * u * p3[0]
        var by = v * v * v * base[1] + 3 * v * v * u * p1[1] + 3 * v * u * u * p2[1] + u * u * u * p3[1]
        var r = u < 0.6 ? lerp(1.8, 4.2, Math.sin(u / 0.6 * Math.PI / 2)) : lerp(4.2, 3.4, (u - 0.6) / 0.4)
        tailPts.push([bx, by, r])
        if (u >= 0.7) tipPts.push([bx, by, r])
    }
    paint(chain(tailPts), TAIL)
    paint(chain(tipPts), TAIL_TIP)
    // Torso cuts a one-pixel gap into the tail instead of drawing an outline.
    paint(torsoShape, BODY, [TAIL, TAIL_TIP])

    // --- Volume: darker belly and haunch under the lit back. ------------------------------
    var belly = [lerpPt(torso[6], torso[5], 0.1), torso[6], torso[7], torso[8], torso[0], [torso[0][0] - 1, torso[0][1] - 2.8], [torso[8][0], torso[8][1] - 2.6], [torso[7][0], torso[7][1] - 2.4], [torso[6][0] - 1, torso[6][1] - 2.8]]
    paint(poly(belly), SHADE, null, [BODY])

    // --- Chest bib. -------------------------------------------------------------------------
    // --- Near legs after the torso so lying forepaws lie in front of it. ---------------------
    drawLeg(nearHind)
    drawLeg(nearFront, up < 0.5 ? [BODY] : null)

    var chestTop = lerpPt(torso[4], torso[5], 0.7)
    var bib = [lerpPt(chestTop, torso[5], 0.2), torso[5], torso[6], lerpPt(torso[6], torso[7], 0.4), lerpPt(lerpPt(torso[7], torso[4], 0.6), torso[6], 0.35)]
    paint(poly(bib), LIGHT, null, [BODY, SHADE])


    // --- Head. Same size lying and standing: it only travels, tilts and turns. ---------------
    var anchor = lerpPt([39, 20.4], [41.8, 13.5], up)
    var tilt = lerp(0.1, -0.05, up) + py * 0.12 - look * 0.1
    var dx = anchor[0] + px * lerp(1.4, 1.0, up) - look * 0.4, dy = anchor[1] + py * 1.0 - look * 1.8
    var ct = Math.cos(tilt), st = Math.sin(tilt)
    function H_(p) { return [dx + p[0] * ct - p[1] * st, dy + p[0] * st + p[1] * ct] }
    function headPoly(pts) { return poly(pts.map(H_)) }
    function tipTri(t, f) { return [t[0], lerpPt(t[0], t[1], f), lerpPt(t[0], t[2], f)] }
    var ear1 = [[-5, -12], [-6.8, -3], [-1.6, -5]]
    var ear2 = [[2.4, -12.2], [-1.6, -5], [3.6, -3.4]]
    var sil = [[-6, 3.5], [-6.6, -1], [-5, -4], [-1, -5], [3, -3.6], [8, -0.6], [8.6, 1.6], [5, 3.2], [0, 5.2], [-4, 5.6], [-7.2, 5.2]]
    var cheek = [[-6, 3.6], [-5.2, 1.6], [-2, 2.6], [2, 1.7], [8.6, 1.8], [5, 3.2], [0, 5.2], [-4, 5.6], [-7.2, 5.2]]
    // The neck always joins head and torso, so rising never toggles a seam.
    var neck = [torso[4], H_([-5.5, -3]), H_([-3, 4.5]), torso[5]]
    paint(poly(neck), BODY)
    paint(headPoly(ear1), BODY); paint(headPoly(ear2), BODY)
    paint(headPoly(sil), BODY)
    paint(headPoly(tipTri(ear1, 0.45)), DARK); paint(headPoly(tipTri(ear2, 0.45)), DARK)
    paint(headPoly(cheek), LIGHT)
    // Muzzle tip and a slanted eye stroke; the eye glides a little inside the head.
    var ex = px * 0.7, ey = py * 0.5
    paint(chain([H_([8.1, 0.2]), H_([8.1, 0.5])].map(function (p) { return [p[0], p[1], 1.1] })), DARK)
    var e0 = H_([-1 + ex, -1.7 + ey]), e1 = H_([2.6 + ex, -0.2 + ey])
    paint(chain([[e0[0], e0[1], 0.55], [e1[0], e1[1], 0.55]]), EYE)
    return buf
}

function render(pose) {
    var full = draw(pose), out = new Array(W * H)
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) out[y * W + x] = full[(y + MARGIN) * BW + x + MARGIN]
    return out
}

// Bounding box of every painted cell, in sprite coordinates and before the crop.
// Anything outside 0..W-1 / 0..H-1 would be cut off by render().
function measure(pose) {
    var full = draw(pose), r = { minX: 1e9, maxX: -1e9, minY: 1e9, maxY: -1e9 }
    for (var i = 0; i < full.length; i++) if (full[i]) {
        var x = i % BW - MARGIN, y = Math.floor(i / BW) - MARGIN
        r.minX = Math.min(r.minX, x); r.maxX = Math.max(r.maxX, x); r.minY = Math.min(r.minY, y); r.maxY = Math.max(r.maxY, y)
    }
    return r
}

if (typeof module !== "undefined") module.exports = { render: render, measure: measure, W: W, H: H }
