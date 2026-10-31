pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: root
    property string name: ""
    property color ink: "white"
    implicitWidth: 18
    implicitHeight: 18
    antialiasing: true
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = ink
        c.lineWidth = 1.8
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (name === "terminal") {
            c.rect(2.5, 4, 19, 16)
            c.moveTo(6.5, 9); c.lineTo(9.5, 12); c.lineTo(6.5, 15)
            c.moveTo(12, 15); c.lineTo(17, 15)
        } else if (name === "files") {
            c.moveTo(3, 7); c.lineTo(3, 18.5); c.quadraticCurveTo(3, 20, 4.5, 20)
            c.lineTo(19.5, 20); c.quadraticCurveTo(21, 20, 21, 18.5)
            c.lineTo(21, 8); c.quadraticCurveTo(21, 6.5, 19.5, 6.5)
            c.lineTo(11.5, 6.5); c.lineTo(9.5, 4.5); c.lineTo(4.5, 4.5)
            c.quadraticCurveTo(3, 4.5, 3, 6); c.lineTo(3, 7)
            c.moveTo(3, 9.5); c.lineTo(21, 9.5)
        } else if (name === "widgets") {
            c.rect(3, 3, 7, 7)
            c.rect(14, 3, 7, 7)
            c.rect(3, 14, 7, 7)
            c.rect(14, 14, 7, 7)
        }
        c.stroke()
    }
}
