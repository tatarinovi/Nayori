pragma ComponentBehavior: Bound

import QtQuick

// Временный знак вместо логотипа. Линии, не файл.
Canvas {
    id: root

    required property color ink

    width: 20
    height: 20
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = root.ink
        ctx.lineWidth = 1.6
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(width * 0.22, height * 0.78)
        ctx.lineTo(width * 0.22, height * 0.22)
        ctx.lineTo(width * 0.78, height * 0.78)
        ctx.lineTo(width * 0.78, height * 0.22)
        ctx.stroke()
    }
}
