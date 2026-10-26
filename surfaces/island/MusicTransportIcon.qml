import QtQuick

Canvas {
    property string name
    property color ink
    property real stroke: 2
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = ink
        c.lineWidth = stroke
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (name === "prev") {
            c.moveTo(19, 20); c.lineTo(9, 12); c.lineTo(19, 4); c.closePath()
            c.moveTo(5, 19); c.lineTo(5, 5)
        } else if (name === "next") {
            c.moveTo(5, 4); c.lineTo(15, 12); c.lineTo(5, 20); c.closePath()
            c.moveTo(19, 5); c.lineTo(19, 19)
        } else if (name === "play") {
            c.moveTo(6, 3); c.lineTo(20, 12); c.lineTo(6, 21); c.closePath()
        } else if (name === "pause") {
            c.roundedRect(5, 4, 4, 16, 1, 1)
            c.roundedRect(15, 4, 4, 16, 1, 1)
        } else if (name === "check") {
            c.moveTo(5, 12); c.lineTo(10, 17); c.lineTo(19, 7)
        } else if (name === "chevronDown") {
            c.moveTo(6, 9); c.lineTo(12, 15); c.lineTo(18, 9)
        } else if (name === "chevronUp") {
            c.moveTo(6, 15); c.lineTo(12, 9); c.lineTo(18, 15)
        } else if (name === "music") {
            c.moveTo(10, 18); c.lineTo(10, 5); c.lineTo(20, 3); c.lineTo(20, 16)
            c.moveTo(10, 18); c.ellipse(3, 16, 7, 5)
            c.moveTo(20, 16); c.ellipse(13, 14, 7, 5)
        }
        c.stroke()
    }
}
