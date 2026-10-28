// Pure accent roles for Tokens.qml. No Qt, no second palette.
// Authored sRGB when derived is false. Otherwise one OKLCH hue from `source`.

var AUTHORED_ACCENT = "#C0AFD1"      // oklch(0.780 0.050 308)
var AUTHORED_SOFT = "#80758C"        // oklch(0.580 0.038 308)
var AUTHORED_TEXT = "#121217"
var BACKGROUND = "#121217"
var TEXT = "#F0E9DB"
var BLACK = "#000000"
var WHITE = "#FFFFFF"
// Authored pair: L 0.780 → 0.580, C 0.050 → 0.038.
var LIGHTNESS_STEP = 0.2
var CHROMA_SCALE = 0.76
var MARK_CONTRAST = 3
var TEXT_CONTRAST = 4.5
// Stop lifting before the accent turns into paper-white. Hue stays put.
var LIGHTNESS_CAP = 0.93

function authoredRoles() {
    return {
        accent: AUTHORED_ACCENT,
        accentSoft: AUTHORED_SOFT,
        accentHover: AUTHORED_SOFT,
        accentText: AUTHORED_TEXT,
        accentSoftText: TEXT,
        accentBorder: AUTHORED_ACCENT
    }
}

function parseColor(input) {
    if (input && typeof input === "object" && typeof input.r === "number") {
        var scale = (input.r > 1 || input.g > 1 || input.b > 1) ? 1 : 255
        return {
            r: clampByte(Math.round(input.r * scale)),
            g: clampByte(Math.round(input.g * scale)),
            b: clampByte(Math.round(input.b * scale))
        }
    }
    var s = String(input == null ? "" : input).trim()
    if (s.charAt(0) === "#")
        s = s.slice(1)
    if (s.length === 3 || s.length === 4)
        s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2] + (s.length === 4 ? s[3] + s[3] : "")
    // Qt hands opaque colors to JS as #AARRGGBB.
    if (s.length === 8)
        s = s.slice(2)
    if (!/^[0-9a-fA-F]{6}$/.test(s))
        return { r: 0, g: 0, b: 0 }
    return {
        r: parseInt(s.slice(0, 2), 16),
        g: parseInt(s.slice(2, 4), 16),
        b: parseInt(s.slice(4, 6), 16)
    }
}

function clampByte(n) {
    return Math.max(0, Math.min(255, n))
}

function hexByte(n) {
    var s = clampByte(n).toString(16).toUpperCase()
    return s.length === 1 ? "0" + s : s
}

function rgbToHex(r, g, b) {
    return "#" + hexByte(r) + hexByte(g) + hexByte(b)
}

function normalizeHex(input) {
    var p = parseColor(input)
    return rgbToHex(p.r, p.g, p.b)
}

// WCAG 2 relative luminance. Threshold 0.03928 is the WCAG piecewise sRGB curve.
function channelLuminance(byte) {
    var c = byte / 255
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function luminance(color) {
    var p = parseColor(color)
    return 0.2126 * channelLuminance(p.r) + 0.7152 * channelLuminance(p.g) + 0.0722 * channelLuminance(p.b)
}

function contrast(c1, c2) {
    var a = luminance(c1)
    var b = luminance(c2)
    var hi = Math.max(a, b)
    var lo = Math.min(a, b)
    return (hi + 0.05) / (lo + 0.05)
}

// CSS Color 4 / Ottosson OKLab. Linearization uses the IEC threshold 0.04045.
function linearByte(byte) {
    var c = byte / 255
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function toOklch(color) {
    var p = parseColor(color)
    var r = linearByte(p.r)
    var g = linearByte(p.g)
    var b = linearByte(p.b)
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    var L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    var A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    var B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    var C = Math.sqrt(A * A + B * B)
    var H = Math.atan2(B, A) * 180 / Math.PI
    if (H < 0)
        H += 360
    return { L: L, C: C, H: H }
}

function linearOklch(L, C, H) {
    var rad = H * Math.PI / 180
    var A = C * Math.cos(rad)
    var B = C * Math.sin(rad)
    var l_ = L + 0.3963377774 * A + 0.2158037573 * B
    var m_ = L - 0.1055613458 * A - 0.0638541728 * B
    var s_ = L - 0.0894841775 * A - 1.2914855480 * B
    var l = l_ * l_ * l_
    var m = m_ * m_ * m_
    var s = s_ * s_ * s_
    return [
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    ]
}

function inGamut(rgb) {
    return rgb[0] >= -0.0001 && rgb[0] <= 1.0001
        && rgb[1] >= -0.0001 && rgb[1] <= 1.0001
        && rgb[2] >= -0.0001 && rgb[2] <= 1.0001
}

function encodeByte(linear) {
    var c = Math.min(1, Math.max(0, linear))
    var encoded = c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055
    return clampByte(Math.round(encoded * 255))
}

// Drop chroma until the color fits sRGB. Lightness and hue stay fixed.
function fitChroma(L, C, H) {
    if (!(C > 0))
        return 0
    if (inGamut(linearOklch(L, C, H)))
        return C
    var lo = 0
    var hi = C
    for (var i = 0; i < 24; i++) {
        var mid = (lo + hi) / 2
        if (inGamut(linearOklch(L, mid, H)))
            lo = mid
        else
            hi = mid
    }
    return lo
}

function oklchToHex(L, C, H) {
    var rgb = linearOklch(L, C, H)
    return rgbToHex(encodeByte(rgb[0]), encodeByte(rgb[1]), encodeByte(rgb[2]))
}

function resolveAccent(source) {
    var hex = normalizeHex(source)
    var o = toOklch(hex)
    if (contrast(hex, BACKGROUND) >= MARK_CONTRAST)
        return { L: o.L, C: o.C, H: o.H, hex: hex }
    var capC = fitChroma(LIGHTNESS_CAP, o.C, o.H)
    var capHex = oklchToHex(LIGHTNESS_CAP, capC, o.H)
    if (contrast(capHex, BACKGROUND) < MARK_CONTRAST)
        return { L: LIGHTNESS_CAP, C: capC, H: o.H, hex: capHex }
    var lo = o.L
    var hi = LIGHTNESS_CAP
    var best = { L: LIGHTNESS_CAP, C: capC, H: o.H, hex: capHex }
    for (var i = 0; i < 24; i++) {
        var mid = (lo + hi) / 2
        var cFit = fitChroma(mid, o.C, o.H)
        var sample = oklchToHex(mid, cFit, o.H)
        if (contrast(sample, BACKGROUND) >= MARK_CONTRAST) {
            best = { L: mid, C: cFit, H: o.H, hex: sample }
            hi = mid
        } else {
            lo = mid
        }
    }
    return best
}

function mixHex(from, to, t) {
    var a = parseColor(from)
    var b = parseColor(to)
    return rgbToHex(
        clampByte(Math.round(a.r + (b.r - a.r) * t)),
        clampByte(Math.round(a.g + (b.g - a.g) * t)),
        clampByte(Math.round(a.b + (b.b - a.b) * t))
    )
}

// Keep the accent hue where possible, while ensuring it is legible on a surface.
function accentOnSurface(accent, surface) {
    if (contrast(accent, surface) >= TEXT_CONTRAST)
        return normalizeHex(accent)
    var target = contrast(WHITE, surface) >= contrast(BLACK, surface) ? WHITE : BLACK
    var lo = 0
    var hi = 1
    for (var i = 0; i < 24; i++) {
        var mid = (lo + hi) / 2
        if (contrast(mixHex(accent, target, mid), surface) >= TEXT_CONTRAST)
            hi = mid
        else
            lo = mid
    }
    return mixHex(accent, target, hi)
}

function accentInk(accent) {
    var dark = contrast(accent, BACKGROUND)
    var light = contrast(accent, TEXT)
    var useDark = dark >= light
    var base = useDark ? BACKGROUND : TEXT
    var toward = useDark ? BLACK : WHITE
    if ((useDark ? dark : light) >= TEXT_CONTRAST)
        return base
    if (contrast(accent, toward) < TEXT_CONTRAST)
        return toward
    var lo = 0
    var hi = 1
    for (var i = 0; i < 24; i++) {
        var mid = (lo + hi) / 2
        if (contrast(accent, mixHex(base, toward, mid)) >= TEXT_CONTRAST)
            hi = mid
        else
            lo = mid
    }
    var ink = mixHex(base, toward, hi)
    // Quantized mix can land a hair under 4.5. Step until the 8-bit color clears it.
    for (var step = 0; step < 8 && contrast(accent, ink) < TEXT_CONTRAST; step++)
        ink = mixHex(base, toward, Math.min(1, hi + (step + 1) / 256))
    return ink
}

// Preserve wallpaper hue with restrained chroma at a light surface's luminance.
function lightNeutral(source, lightness) {
    var color = toOklch(source)
    var chroma = fitChroma(lightness, Math.min(color.C, 0.025), color.H)
    return oklchToHex(lightness, chroma, color.H)
}

function roles(source, derived, light, surface) {
    if (light === true) {
        var accent = accentOnSurface(derived === true ? source : AUTHORED_ACCENT, surface || "#EBE5F0")
        var soft = mixHex(accent, BLACK, 0.18)
        var hover = mixHex(accent, BLACK, 0.09)
        return {
            accent: accent,
            accentSoft: soft,
            accentHover: hover,
            accentText: accentInk(accent),
            accentSoftText: accentInk(soft),
            accentBorder: accent
        }
    }
    if (derived !== true)
        return authoredRoles()
    var accent = resolveAccent(source)
    var softL = Math.max(0, accent.L - LIGHTNESS_STEP)
    var softC = fitChroma(softL, Math.max(0, accent.C * CHROMA_SCALE), accent.H)
    var hoverL = (accent.L + softL) / 2
    var hoverC = fitChroma(hoverL, Math.max(0, (accent.C + softC) / 2), accent.H)
    var accentHex = accent.hex
    var softHex = oklchToHex(softL, softC, accent.H)
    return {
        accent: accentHex,
        accentSoft: softHex,
        accentHover: oklchToHex(hoverL, hoverC, accent.H),
        accentText: accentInk(accentHex),
        // Ink for text sitting on accentSoft. Same 4.5:1 search as accentText.
        accentSoftText: accentInk(softHex),
        // Borders already follow accent. This is that same non-text mark, after the 3:1 guard.
        accentBorder: accentHex
    }
}
