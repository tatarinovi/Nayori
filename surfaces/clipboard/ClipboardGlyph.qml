import QtQuick

// Small stroke icons independent of font fallback (notably the pin marker).
Canvas {
    id: root
    required property color ink
    property string name: "pin"
    implicitWidth: 16
    implicitHeight: 16
    antialiasing: true
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = root.ink
        c.lineWidth = 1.7
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (name === "pin") {
            c.moveTo(7, 3); c.lineTo(17, 3); c.lineTo(16, 4); c.lineTo(16, 9)
            c.lineTo(19, 13); c.lineTo(19, 15); c.lineTo(5, 15); c.lineTo(5, 13)
            c.lineTo(8, 9); c.lineTo(8, 4); c.lineTo(7, 3)
            c.moveTo(12, 15); c.lineTo(12, 22)
        } else if (name === "trash") {
            c.moveTo(4, 6); c.lineTo(20, 6)
            c.moveTo(9, 6); c.lineTo(9, 3); c.lineTo(15, 3); c.lineTo(15, 6)
            c.moveTo(6, 6); c.lineTo(7, 21); c.lineTo(17, 21); c.lineTo(18, 6)
            c.moveTo(10, 10); c.lineTo(10, 17); c.moveTo(14, 10); c.lineTo(14, 17)
        } else if (name === "close") {
            c.moveTo(6, 6); c.lineTo(18, 18); c.moveTo(18, 6); c.lineTo(6, 18)
        }
        c.stroke()
    }
}
