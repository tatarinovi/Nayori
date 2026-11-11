// Nayori storage adapter for Ryoku VizItem. Unknown instance fields are retained.
var defaults = {
    "id": "",
    "style": "bars",
    "shape": "rounded",
    "bars": 64,
    "thickness": 0.58,
    "bloom": 0.6,
    "reflection": 0.1,
    "idleWave": true,
    "mirror": false,
    "segments": 10,
    "gain": 1.0,
    "smoothing": 0.5,
    "peaks": false,
    "spin": 0,
    "x": 0,
    "y": 0.58,
    "w": 1,
    "h": 0.42,
    "grow": "up",
    "angle": 0,
    "tiltX": 0,
    "tiltY": 0,
    "color": "",
    "color2": "",
    "gradient": false,
    "auraDepth": 180,
    "auraSpan": 1.0,
    "auraTaper": 0.14,
    "auraCornerRadius": 24,
    "auraJoin": "auto",
    "auraCornerBlend": 0.55,
    "auraFlow": "clockwise",
    "auraMaterial": "silk",
    "auraShape": "flow",
    "auraEffect": "clean",
    "auraEffectStrength": 0.38,
    "auraColorMode": "flow",
    "auraColorSpeed": 0.35,
    "auraBodyOpacity": 0.32,
    "auraCrestStrength": 0.9,
    "auraGlow": 0.52,
    "auraGlowSpread": 0.48,
    "auraAudioRange": 0.78,
    "auraThickness": 0.22,
    "auraDetail": 0.42,
    "auraBassDrive": 0.88,
    "auraTrebleDrive": 0.68,
    "auraTransient": 0.9,
    "auraBeatGlow": 0.64,
    "auraCompression": 0.12,
    "auraMotionSpeed": 1.0,
    "auraIdleMotion": 0.14,
    "auraAttack": 1.05,
    "auraRelease": 0.82,
    "auraProfile": "flat",
    "auraAccent": 0.7,
    "auraSensitivity": 0.72,
    "auraOpacity": 1.0,
    "auraColor2": "",
    "auraColor3": "",
    "output": "",
    "enabled": true,
    "auraEdges": [
        "left",
        "right"
    ]
};
var ranges = {"gain": [0.05, 3], "smoothing": [0, 1], "tiltX": [-60, 60], "tiltY": [-60, 60], "bars": [16.0, 128.0], "segments": [3.0, 24.0], "thickness": [0.2, 1.0], "spin": [-30, 30], "reflection": [0, 0.3], "bloom": [0, 1], "auraEffectStrength": [0, 1], "auraColorSpeed": [0, 1], "auraSpan": [0.2, 1], "auraTaper": [0, 0.5], "auraCornerRadius": [0.0, 64.0], "auraCornerBlend": [0, 1], "auraAccent": [0, 1], "auraOpacity": [0.2, 1], "auraBodyOpacity": [0, 1], "auraCrestStrength": [0, 1], "auraGlow": [0, 1], "auraGlowSpread": [0, 1], "auraAudioRange": [0, 1], "auraThickness": [0.05, 0.6], "auraDetail": [0, 1], "auraBassDrive": [0, 1.5], "auraTrebleDrive": [0, 1.5], "auraTransient": [0, 1], "auraBeatGlow": [0, 1], "auraCompression": [0, 1], "auraSensitivity": [0, 2.0], "auraMotionSpeed": [0, 3.0], "auraIdleMotion": [0, 1], "auraAttack": [0.2, 3.0], "auraRelease": [0.2, 3.0], "auraDepth": [24.0, 600.0], "x": [-0.95, 1], "y": [-0.95, 1], "w": [0.05, 1], "h": [0.05, 1], "angle": [0, 360]};
var choices = {"style": ["bars", "split", "dots", "segments", "wave", "ribbon", "curtain", "line", "frame", "radial", "orb", "spiral", "aura"], "shape": ["rounded", "flat"], "grow": ["up", "down", "center", "left", "right"], "auraJoin": ["auto", "separate"], "auraFlow": ["clockwise", "counterclockwise"], "auraMaterial": ["silk", "aurora", "contour", "liquid"], "auraShape": ["flow", "ribbon", "cells", "filament"], "auraEffect": ["clean", "shimmer", "echo", "prism", "bloom", "caustic", "afterglow"], "auraColorMode": ["flow", "spectrum", "pulse", "static"], "auraProfile": ["flat", "bass", "warm", "vocal", "treble", "smile"]};

function normalizeItem(raw) {
    const src = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    const out = Object.assign({}, src);
    for (const key of Object.keys(defaults)) {
        const value = src[key], fallback = defaults[key];
        if (key === "auraEdges") out[key] = Array.isArray(value) ? value.filter((v, i, a) => ["top", "right", "bottom", "left"].indexOf(v) >= 0 && a.indexOf(v) === i) : fallback.slice();
        else if (choices[key]) out[key] = choices[key].indexOf(value) >= 0 ? value : fallback;
        else if (typeof fallback === "number") {
            const r = ranges[key] || [-10000, 10000];
            out[key] = typeof value === "number" && isFinite(value) ? Math.max(r[0], Math.min(r[1], value)) : fallback;
            if (["bars", "segments"].indexOf(key) >= 0) out[key] = Math.round(out[key]);
        } else if (typeof fallback === "boolean") out[key] = typeof value === "boolean" ? value : fallback;
        else out[key] = typeof value === "string" ? value : fallback;
    }
    for (const key of ["color", "color2", "auraColor2", "auraColor3"])
        if (!/^#[0-9a-fA-F]{6}$/.test(out[key])) out[key] = "";
    // Keep a selectable part of every box on screen, including after hotplug.
    out.x = Math.max(-out.w + 0.05, Math.min(0.95, out.x));
    out.y = Math.max(-out.h + 0.05, Math.min(0.95, out.y));
    return out;
}
function normalize(raw) {
    const src = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    const used = Object.create(null);
    const items = (Array.isArray(src.items) ? src.items : []).filter(v => v && typeof v === "object" && !Array.isArray(v)).map((v, i) => {
        const item = normalizeItem(v);
        let id = item.id || "visualizer-" + i;
        while (used[id]) id += "-copy";
        used[id] = true;
        item.id = id;
        return item;
    });
    return Object.assign({}, src, {items: items, fps: [30,45,60].indexOf(src.fps) >= 0 ? src.fps : 30, adaptive: src.adaptive !== false});
}
if (typeof module !== "undefined") module.exports = {defaults, ranges, choices, normalizeItem, normalize};
