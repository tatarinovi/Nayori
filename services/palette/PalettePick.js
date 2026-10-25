// Ranks colors for a wallpaper accent and for the dark neutral surfaces.
// This is not a mean of the samples. Quickshell.ColorQuantizer returns
// 2^depth averages and no weights. Each result is one median-cut bucket of
// roughly equal population, so repeated colors stand in for prevalence.
// Fully transparent samples are dropped. Alpha above 1 is read as a 0..255
// channel. Partial alpha is kept: the quantizer itself only skips alpha 0,
// then stores an opaque average.
//
// The accent scorer is unchanged. Neutrals are a separate pick from the same
// buckets: low chroma, low-to-mid lightness, high prevalence. The chosen
// accent is never used as the background. Near-white is rejected. Near-black
// is kept. A lighter neutral, or a vivid field with no neutral, is rebuilt
// in graphite range (lightness 0.185, chroma at most 0.012) so the shell
// stays a dark neutral. surfaceAlt is the same hue, +0.189 lightness, and
// at most +0.020 chroma (capped at 0.032). surface is the same family,
// +0.246 lightness, chroma at most 0.020. Cream #F0E9DB must stay at least
// 4.5:1; the surface is darkened until it does. No usable neutral, or no
// samples, keeps #121217, #4F4F57, and #443D4E.
var FALLBACK = "#C0AFD1"
var AUTHORED_BACKGROUND = "#121217"
var AUTHORED_SURFACE = "#4F4F57"
var AUTHORED_SURFACE_ALT = "#443D4E"
var INK = "#F0E9DB"
var TEXT_CONTRAST = 4.5
var NEUTRAL_CHROMA = 0.04
var NEAR_WHITE_L = 0.90
var GRAPHITE_L = 0.185
var GRAPHITE_L_MAX = 0.27
var HINT_C = 0.012
var ACHROMA = 0.004
var ALT_STEP = 0.189
var SURF_STEP = 0.246
var ALT_C_EXTRA = 0.020
var SURF_C_EXTRA = 0.003
var ALT_C_CAP = 0.032
var SURF_C_CAP = 0.020

function neutralFallback() {
    return {
        background: AUTHORED_BACKGROUND,
        surface: AUTHORED_SURFACE,
        surfaceAlt: AUTHORED_SURFACE_ALT,
        neutralFallbackUsed: true
    }
}

function fallbackResult() {
    const neutrals = neutralFallback()
    return {
        accent: FALLBACK,
        candidates: [{ color: FALLBACK, share: 1 }],
        fallbackUsed: true,
        background: neutrals.background,
        surface: neutrals.surface,
        surfaceAlt: neutrals.surfaceAlt,
        neutralFallbackUsed: true
    }
}

function linear(channel) {
    const value = channel / 255
    return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

function measure(hex) {
    const parsed = parseColor(hex)
    if (!parsed) return { L: 0, C: 0, H: 0 }
    const number = parseInt(parsed.color.slice(1), 16)
    const red = (number >> 16) & 255
    const green = (number >> 8) & 255
    const blue = number & 255
    const r = linear(red)
    const g = linear(green)
    const b = linear(blue)
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    const a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    const b2 = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    let hue = Math.atan2(b2, a) * 180 / Math.PI
    if (hue < 0) hue += 360
    return {
        L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        C: Math.hypot(a, b2),
        H: hue
    }
}

function parseColor(text) {
    const match = /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.exec(String(text || "").trim())
    if (!match) return null
    const body = match[1]
    const alpha = body.length === 8 ? parseInt(body.slice(0, 2), 16) / 255 : 1
    const rgb = body.length === 8 ? body.slice(2) : body
    return { color: "#" + rgb.toUpperCase(), alpha: alpha }
}

function sampleAlpha(item, parsed) {
    let alpha = item && item.alpha !== undefined && item.alpha !== null && item.alpha !== "" ? item.alpha : parsed.alpha
    alpha = Number(alpha)
    if (!isFinite(alpha)) return 1
    return alpha
}

function roundShare(value) {
    return Math.round(value * 1000000) / 1000000
}

function peak(value, center, sigma) {
    const distance = (value - center) / sigma
    return Math.exp(-0.5 * distance * distance)
}

// Readable on graphite #121217: mid lightness, mid-high chroma.
// Neon chroma falls off instead of being rejected, so a pure red field can still win.
function scoreOf(sample) {
    const chroma = peak(sample.C, 0.09, 0.05)
    const light = peak(sample.L, 0.72, 0.13)
    return sample.share * 0.45 + chroma * 0.35 + light * 0.20
}

function chromatic(sample) {
    return sample.L >= 0.40 && sample.L <= 0.94 && sample.C >= 0.02
}

function byRank(a, b) {
    if (a.score !== b.score) return a.score > b.score ? -1 : 1
    if (a.share !== b.share) return a.share > b.share ? -1 : 1
    return a.index - b.index
}

function rank(colors) {
    if (!colors || typeof colors.length !== "number") return fallbackResult()
    const merged = []
    for (let i = 0; i < colors.length; i++) {
        const item = colors[i]
        if (!item) continue
        const parsed = parseColor(item.color)
        if (!parsed) continue
        const alpha = sampleAlpha(item, parsed)
        if (alpha <= 0) continue
        const share = Number(item.share)
        const positive = isFinite(share) && share > 0 ? share : 0
        let existing = null
        for (let j = 0; j < merged.length; j++) {
            if (merged[j].color === parsed.color) { existing = merged[j]; break }
        }
        if (!existing) merged.push({ color: parsed.color, share: positive, count: 1, index: i })
        else { existing.share += positive; existing.count += 1 }
    }
    if (!merged.length) return fallbackResult()
    let anyShare = false
    let total = 0
    for (let i = 0; i < merged.length; i++) {
        total += merged[i].count
        if (merged[i].share > 0) anyShare = true
    }
    if (!anyShare) {
        for (let i = 0; i < merged.length; i++) merged[i].share = merged[i].count / total
    }
    const usable = []
    for (let i = 0; i < merged.length; i++) {
        const sample = merged[i]
        const lab = measure(sample.color)
        sample.L = lab.L
        sample.C = lab.C
        sample.H = lab.H
        if (!chromatic(sample)) continue
        sample.score = scoreOf(sample)
        usable.push(sample)
    }
    let accent = FALLBACK
    let candidates = [{ color: FALLBACK, share: 1 }]
    let accentFallback = true
    if (usable.length) {
        usable.sort(byRank)
        candidates = []
        for (let i = 0; i < usable.length; i++) {
            candidates.push({ color: usable[i].color, share: roundShare(usable[i].share) })
        }
        accent = candidates[0].color
        accentFallback = false
    }
    const neutrals = rankNeutrals(merged, accentFallback ? "" : accent)
    return {
        accent: accent,
        candidates: candidates,
        fallbackUsed: accentFallback,
        background: neutrals.background,
        surface: neutrals.surface,
        surfaceAlt: neutrals.surfaceAlt,
        neutralFallbackUsed: neutrals.neutralFallbackUsed
    }
}

function channelLuminance(byte) {
    const value = byte / 255
    return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

function contrast(first, second) {
    const a = luminance(first)
    const b = luminance(second)
    const hi = Math.max(a, b)
    const lo = Math.min(a, b)
    return (hi + 0.05) / (lo + 0.05)
}

function luminance(hex) {
    const parsed = parseColor(hex)
    if (!parsed) return 0
    const number = parseInt(parsed.color.slice(1), 16)
    const red = (number >> 16) & 255
    const green = (number >> 8) & 255
    const blue = number & 255
    return 0.2126 * channelLuminance(red) + 0.7152 * channelLuminance(green) + 0.0722 * channelLuminance(blue)
}

function linearOklch(L, C, H) {
    const rad = H * Math.PI / 180
    const A = C * Math.cos(rad)
    const B = C * Math.sin(rad)
    const l_ = L + 0.3963377774 * A + 0.2158037573 * B
    const m_ = L - 0.1055613458 * A - 0.0638541728 * B
    const s_ = L - 0.0894841775 * A - 1.2914855480 * B
    const l = l_ * l_ * l_
    const m = m_ * m_ * m_
    const s = s_ * s_ * s_
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

function encodeByte(linearChannel) {
    const c = Math.min(1, Math.max(0, linearChannel))
    const encoded = c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055
    return Math.max(0, Math.min(255, Math.round(encoded * 255)))
}

function fitChroma(L, C, H) {
    if (!(C > 0)) return 0
    if (inGamut(linearOklch(L, C, H))) return C
    let lo = 0
    let hi = C
    for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2
        if (inGamut(linearOklch(L, mid, H))) lo = mid
        else hi = mid
    }
    return lo
}

function oklchToHex(L, C, H) {
    const rgb = linearOklch(L, C, H)
    const red = encodeByte(rgb[0])
    const green = encodeByte(rgb[1])
    const blue = encodeByte(rgb[2])
    function byte(value) {
        const text = value.toString(16).toUpperCase()
        return text.length === 1 ? "0" + text : text
    }
    return "#" + byte(red) + byte(green) + byte(blue)
}

function darkenForInk(L, C, H) {
    let chroma = fitChroma(L, C, H)
    let hex = oklchToHex(L, chroma, H)
    if (contrast(hex, INK) >= TEXT_CONTRAST) return { L: L, C: chroma, H: H, hex: hex }
    let lo = 0
    let hi = L
    let bestL = 0
    let bestC = fitChroma(0, C, H)
    let bestHex = oklchToHex(0, bestC, H)
    for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2
        const fitted = fitChroma(mid, C, H)
        const sample = oklchToHex(mid, fitted, H)
        if (contrast(sample, INK) >= TEXT_CONTRAST) {
            bestL = mid
            bestC = fitted
            bestHex = sample
            lo = mid
        } else {
            hi = mid
        }
    }
    let guard = 0
    while (contrast(bestHex, INK) < TEXT_CONTRAST && bestL > 0 && guard < 12) {
        bestL = Math.max(0, bestL - 0.005)
        bestC = fitChroma(bestL, C, H)
        bestHex = oklchToHex(bestL, bestC, H)
        guard++
    }
    return { L: bestL, C: bestC, H: H, hex: bestHex }
}

function liftSurfaces(L, C, H) {
    const background = darkenForInk(L, C, H)
    const baseC = C < ACHROMA ? 0 : C
    const altC = baseC === 0 ? 0 : Math.min(ALT_C_CAP, baseC + ALT_C_EXTRA)
    const surfC = baseC === 0 ? 0 : Math.min(SURF_C_CAP, baseC + SURF_C_EXTRA)
    const surfaceAlt = darkenForInk(background.L + ALT_STEP, altC, H)
    const surface = darkenForInk(background.L + SURF_STEP, surfC, H)
    return {
        background: background.hex,
        surface: surface.hex,
        surfaceAlt: surfaceAlt.hex,
        neutralFallbackUsed: false
    }
}

function paintNeutral(sample, crush) {
    let L = sample.L
    let C = sample.C
    const H = sample.H || 0
    let kept = ""
    if (crush || L > GRAPHITE_L_MAX) {
        L = GRAPHITE_L
        C = C < ACHROMA ? 0 : Math.min(C, HINT_C)
    } else if (contrast(sample.color, INK) >= TEXT_CONTRAST) {
        kept = sample.color
    }
    const painted = liftSurfaces(L, C, H)
    if (kept) painted.background = kept
    return painted
}

function neutralScore(sample) {
    const chroma = Math.exp(-0.5 * Math.pow(sample.C / 0.02, 2))
    const light = Math.exp(-0.5 * Math.pow((sample.L - 0.20) / 0.18, 2))
    return sample.share * 0.50 + chroma * 0.30 + light * 0.20
}

function byNeutral(a, b) {
    if (a.neutralScore !== b.neutralScore) return a.neutralScore > b.neutralScore ? -1 : 1
    if (a.share !== b.share) return a.share > b.share ? -1 : 1
    return a.index - b.index
}

function dominantSample(samples) {
    let best = null
    for (let i = 0; i < samples.length; i++) {
        const sample = samples[i]
        if (sample.L >= NEAR_WHITE_L) continue
        if (!best || sample.share > best.share || (sample.share === best.share && sample.index < best.index))
            best = sample
    }
    return best
}

function rankNeutrals(samples, accentHex) {
    const neutrals = []
    for (let i = 0; i < samples.length; i++) {
        const sample = samples[i]
        if (accentHex && sample.color === accentHex) continue
        if (sample.C > NEUTRAL_CHROMA || sample.L >= NEAR_WHITE_L) continue
        sample.neutralScore = neutralScore(sample)
        neutrals.push(sample)
    }
    if (neutrals.length) {
        neutrals.sort(byNeutral)
        const painted = paintNeutral(neutrals[0], false)
        if (painted.background !== accentHex) return painted
    }
    const source = dominantSample(samples)
    if (!source) return neutralFallback()
    const crushed = paintNeutral(source, true)
    if (accentHex && crushed.background === accentHex) return neutralFallback()
    return crushed
}
