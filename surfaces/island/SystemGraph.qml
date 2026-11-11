import QtQuick

Canvas {
    id: root
    objectName: "systemGraph"
    property var points: []
    property color accent: "white"
    property real ceiling: 100
    property double now: points.length ? points[points.length - 1].t : 0
    onPointsChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        if (width <= 0 || height <= 0 || points.length < 2) return
        const maximum = ceiling > 0 ? ceiling : Math.max(1, ...points.map(p => p.v || 0)) * 1.15
        const x = p => width * Math.max(0, Math.min(1, (p.t - now + 60) / 60))
        const y = p => height - 2 - (height - 4) * Math.max(0, Math.min(1, p.v / maximum))
        const segments = []
        let segment = []
        for (const p of points) {
            if (p.v === null || p.v === undefined || !isFinite(p.v) || (segment.length && p.t - segment[segment.length - 1].t > 2.5)) {
                if (segment.length) segments.push(segment)
                segment = []
            }
            if (p.v !== null && p.v !== undefined && isFinite(p.v)) segment.push(p)
        }
        if (segment.length) segments.push(segment)
        for (const samples of segments) {
            if (samples.length < 2) continue
            const trace = () => {
                c.moveTo(x(samples[0]), y(samples[0]))
                for (let i = 1; i < samples.length; i++) {
                    const a = samples[i - 1], b = samples[i], mid = (x(a) + x(b)) / 2
                    c.bezierCurveTo(mid, y(a), mid, y(b), x(b), y(b))
                }
            }
            c.beginPath(); trace()
            c.lineTo(x(samples[samples.length - 1]), height); c.lineTo(x(samples[0]), height); c.closePath()
            const gradient = c.createLinearGradient(0, 0, 0, height)
            gradient.addColorStop(0, Qt.alpha(accent, 0.34)); gradient.addColorStop(1, Qt.alpha(accent, 0.02))
            c.fillStyle = gradient; c.fill()
            c.beginPath(); trace(); c.strokeStyle = accent; c.lineWidth = 1.5; c.stroke()
        }
    }
}
