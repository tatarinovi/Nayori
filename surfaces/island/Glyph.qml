import QtQuick

// Рисованные значки острова на сетке 24×24. Не зависят от установленных шрифтов иконок.
// name: terminal battery bell chat chevronUp chevronDown chevronRight trash grid dot gear
//       close plus reply prev next play pause list
Canvas {
    id: root
    property string name: ""
    property color ink: "white"
    // Заливка-акцент (например, заряд в батарее); по умолчанию совпадает с ink.
    property color fill: ink
    // Толщина линии в клетках сетки 24×24.
    property real stroke: 2
    implicitWidth: 16
    implicitHeight: 16
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onFillChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        if (width <= 0 || height <= 0) return
        c.scale(width / 24, height / 24)
        c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = stroke
        c.lineCap = "round"; c.lineJoin = "round"
        c.beginPath()
        switch (name) {
        case "terminal":
            c.roundedRect(3, 5, 18, 14, 3, 3)
            c.moveTo(7, 10); c.lineTo(10.5, 12.5); c.lineTo(7, 15)
            c.moveTo(12.5, 15); c.lineTo(17, 15)
            c.stroke(); break
        case "battery":
            c.roundedRect(2.5, 7, 17, 10, 2.5, 2.5)
            c.stroke()
            c.beginPath(); c.moveTo(22, 10.5); c.lineTo(22, 13.5); c.stroke()
            c.fillStyle = fill; c.beginPath(); c.roundedRect(4.8, 9.3, 3.6, 5.4, 1, 1); c.fill(); break
        case "bell":
            c.moveTo(6, 17); c.lineTo(6, 11); c.bezierCurveTo(6, 7.5, 8.5, 5.5, 12, 5.5)
            c.bezierCurveTo(15.5, 5.5, 18, 7.5, 18, 11); c.lineTo(18, 17); c.lineTo(20, 18); c.lineTo(4, 18); c.lineTo(6, 17)
            c.moveTo(10, 20.5); c.lineTo(14, 20.5)
            c.stroke(); break
        case "chat":
            c.roundedRect(3, 4, 18, 13, 4.5, 4.5)
            c.moveTo(8.5, 17); c.lineTo(7.5, 21); c.lineTo(12.5, 17)
            c.stroke()
            c.beginPath(); c.arc(8.5, 10.5, 1.2, 0, Math.PI * 2); c.arc(12, 10.5, 1.2, 0, Math.PI * 2); c.arc(15.5, 10.5, 1.2, 0, Math.PI * 2); c.fill(); break
        case "chevronUp":
            c.moveTo(6, 15); c.lineTo(12, 9); c.lineTo(18, 15); c.stroke(); break
        case "chevronDown":
            c.moveTo(6, 9); c.lineTo(12, 15); c.lineTo(18, 9); c.stroke(); break
        case "chevronRight":
            c.moveTo(9, 6); c.lineTo(15, 12); c.lineTo(9, 18); c.stroke(); break
        case "trash":
            c.moveTo(4.5, 7); c.lineTo(19.5, 7)
            c.moveTo(9, 7); c.lineTo(9, 4.5); c.lineTo(15, 4.5); c.lineTo(15, 7)
            c.moveTo(6.5, 7); c.lineTo(7.5, 19.5); c.lineTo(16.5, 19.5); c.lineTo(17.5, 7)
            c.moveTo(10.2, 10.5); c.lineTo(10.2, 16); c.moveTo(13.8, 10.5); c.lineTo(13.8, 16)
            c.stroke(); break
        case "grid":
            c.roundedRect(4, 4, 6.5, 6.5, 1.8, 1.8); c.roundedRect(13.5, 4, 6.5, 6.5, 1.8, 1.8)
            c.roundedRect(4, 13.5, 6.5, 6.5, 1.8, 1.8); c.roundedRect(13.5, 13.5, 6.5, 6.5, 1.8, 1.8)
            c.fill(); break
        case "dot":
            c.arc(12, 12, 4.5, 0, Math.PI * 2); c.fill(); break
        case "gear":
            c.arc(12, 12, 3, 0, Math.PI * 2)
            c.moveTo(18.2, 12); c.arc(12, 12, 6.2, 0, Math.PI * 2)
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4
                c.moveTo(12 + Math.cos(a) * 6.2, 12 + Math.sin(a) * 6.2); c.lineTo(12 + Math.cos(a) * 9, 12 + Math.sin(a) * 9)
            }
            c.stroke(); break
        case "close":
            c.moveTo(7, 7); c.lineTo(17, 17); c.moveTo(17, 7); c.lineTo(7, 17); c.stroke(); break
        case "plus":
            c.moveTo(12, 6); c.lineTo(12, 18); c.moveTo(6, 12); c.lineTo(18, 12); c.stroke(); break
        case "reply":
            c.moveTo(10, 6); c.lineTo(4.5, 11.5); c.lineTo(10, 17)
            c.moveTo(4.5, 11.5); c.lineTo(13, 11.5); c.bezierCurveTo(17.5, 11.5, 19.5, 14, 19.5, 18.5)
            c.stroke(); break
        case "prev":
            c.moveTo(18.5, 5.5); c.lineTo(9, 12); c.lineTo(18.5, 18.5); c.closePath(); c.fill()
            c.fillRect(5, 5.5, 2.6, 13); break
        case "next":
            c.moveTo(5.5, 5.5); c.lineTo(15, 12); c.lineTo(5.5, 18.5); c.closePath(); c.fill()
            c.fillRect(16.4, 5.5, 2.6, 13); break
        case "play":
            c.moveTo(7.5, 4.5); c.lineTo(19, 12); c.lineTo(7.5, 19.5); c.closePath(); c.fill(); break
        case "pause":
            c.roundedRect(6, 5, 4, 14, 1, 1); c.roundedRect(14, 5, 4, 14, 1, 1); c.fill(); break
        case "list":
            c.moveTo(5, 7); c.lineTo(19, 7); c.moveTo(5, 12); c.lineTo(19, 12); c.moveTo(5, 17); c.lineTo(19, 17); c.stroke(); break
        }
    }
}
