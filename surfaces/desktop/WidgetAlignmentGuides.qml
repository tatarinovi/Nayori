pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: root
    required property var tokens
    property var box: null
    objectName: "desktop-widget-alignment-guides"
    property color ink: Qt.alpha(tokens.color.accent, 0.45)
    onBoxChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (!visible || !box) return
        ctx.strokeStyle = ink
        ctx.lineWidth = 1
        const left = Math.round(box.x) + 0.5
        const right = Math.round(box.x + box.width) + 0.5
        const top = Math.round(box.y) + 0.5
        const bottom = Math.round(box.y + box.height) + 0.5
        ctx.beginPath()
        for (const x of [left, right]) {
            ctx.moveTo(x, 0); ctx.lineTo(x, top)
            ctx.moveTo(x, bottom); ctx.lineTo(x, height)
        }
        for (const y of [top, bottom]) {
            ctx.moveTo(0, y); ctx.lineTo(left, y)
            ctx.moveTo(right, y); ctx.lineTo(width, y)
        }
        ctx.stroke()
    }
}
