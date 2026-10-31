import QtQuick

// Штриховые значки лаунчера: лупа, «ввод» и стрелка действия. Цвет задаёт хост из токенов.
Canvas {
    id: root

    property string kind: "search"
    required property color ink
    property real stroke: 1.8

    implicitWidth: 24
    implicitHeight: 24
    antialiasing: true

    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = root.ink
        c.lineWidth = root.stroke
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (kind === "search") {
            c.arc(10.5, 10.5, 6.5, 0, Math.PI * 2)
            c.moveTo(15.4, 15.4)
            c.lineTo(20, 20)
        } else if (kind === "enter") {
            c.moveTo(19, 5)
            c.lineTo(19, 12)
            c.lineTo(5, 12)
            c.moveTo(9.5, 7.5)
            c.lineTo(5, 12)
            c.lineTo(9.5, 16.5)
        } else if (kind === "next") {
            c.moveTo(4, 12)
            c.lineTo(20, 12)
            c.moveTo(14, 6)
            c.lineTo(20, 12)
            c.lineTo(14, 18)
        } else if (kind === "file") {
            c.moveTo(7, 3)
            c.lineTo(14, 3)
            c.lineTo(18, 7)
            c.lineTo(18, 21)
            c.lineTo(6, 21)
            c.lineTo(6, 3)
            c.closePath()
            c.moveTo(14, 3)
            c.lineTo(14, 7)
            c.lineTo(18, 7)
        } else if (kind === "folder") {
            c.moveTo(3, 8)
            c.lineTo(9, 8)
            c.lineTo(11, 5)
            c.lineTo(21, 5)
            c.lineTo(21, 19)
            c.lineTo(3, 19)
            c.closePath()
        } else if (kind === "command") {
            c.moveTo(4, 7)
            c.lineTo(10, 12)
            c.lineTo(4, 17)
            c.moveTo(12, 18)
            c.lineTo(20, 18)
        }
        c.stroke()
    }
}
