// Modified for Nayori, 2026-11-11: extracted pure colour math.
import QtQuick
QtObject {
    required property var colorUtils
    function mark(seed: color, level: real, spread: real, darkInk: bool, contrast: real): color {
        const c = Qt.color(seed)
        if (level < 0 || c.hslSaturation < 0.08) return c
        const worst = Math.pow(darkInk ? Math.max(0, level - spread) : Math.min(1, level + spread), 2.2)
        const hue = Math.max(0, c.hslHue)
        let l = c.hslLightness
        let out = c
        for (let i = 0; i < 48; i++) {
            const lean = darkInk && hue > 0.05 && hue < 0.17 ? Math.min(1, (c.hslLightness - l) * 2.5) : 0
            out = Qt.hsla(hue - (hue - 0.04) * lean, c.hslSaturation, l, 1)
            const own = colorUtils.relativeLuminance(out)
            const ratio = darkInk ? (worst + 0.05) / (own + 0.05) : (own + 0.05) / (worst + 0.05)
            if (ratio >= contrast || l <= 0.08 || l >= 0.94) break
            l += darkInk ? -0.02 : 0.02
        }
        return out
    }

}
