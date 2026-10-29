import QtQuick

Canvas {
    id: root
    property string name: "wifi"
    property color ink: "white"
    property real strength: 1
    implicitWidth: 22
    implicitHeight: 22
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.strokeStyle = ink
        c.fillStyle = ink
        c.lineWidth = 1.5
        c.lineCap = "round"
        c.lineJoin = "round"
        c.beginPath()
        if (name === "ethernet") {
            c.moveTo(4, 3); c.lineTo(20, 3); c.lineTo(20, 15)
            c.lineTo(16, 15); c.lineTo(16, 20); c.lineTo(8, 20)
            c.lineTo(8, 15); c.lineTo(4, 15); c.closePath()
            for (let i = 8; i <= 16; i += 4) { c.moveTo(i, 3); c.lineTo(i, 8) }
        } else if (name === "shield") {
            c.moveTo(12, 2); c.quadraticCurveTo(16, 5, 20, 5)
            c.lineTo(20, 12); c.quadraticCurveTo(19, 18, 12, 22)
            c.quadraticCurveTo(5, 18, 4, 12); c.lineTo(4, 5)
            c.quadraticCurveTo(8, 5, 12, 2)
        } else if (name === "lock") {
            c.rect(6, 10, 12, 10)
            c.moveTo(8, 10); c.lineTo(8, 7); c.arc(12, 7, 4, Math.PI, 0); c.lineTo(16, 10)
        } else if (name === "back" || name === "next") {
            const x = name === "back" ? 14 : 10
            const y = name === "back" ? 8 : 16
            c.moveTo(x, 6); c.lineTo(y, 12); c.lineTo(x, 18)
        } else if (name === "close") {
            c.moveTo(6, 6); c.lineTo(18, 18); c.moveTo(18, 6); c.lineTo(6, 18)
        } else if (name === "check") {
            c.moveTo(5, 12); c.lineTo(10, 17); c.lineTo(19, 7)
        } else if (name === "settings") {
            for (let i = 0; i < 32; i++) {
                const angle = i * Math.PI / 16 - Math.PI / 8
                const radius = i % 4 === 1 || i % 4 === 2 ? 9 : 7
                const x = 12 + Math.cos(angle) * radius
                const y = 12 + Math.sin(angle) * radius
                if (i === 0) c.moveTo(x, y)
                else c.lineTo(x, y)
            }
            c.closePath(); c.moveTo(15, 12); c.arc(12, 12, 3, 0, Math.PI * 2)
        } else {
            c.stroke()
            for (let i = 0; i < 3; i++) {
                c.globalAlpha = strength >= (3 - i) / 4 ? 1 : 0.22
                c.beginPath()
                c.arc(12, 20, 6 + (2 - i) * 5, Math.PI * 1.25, Math.PI * 1.75)
                c.stroke()
            }
            c.globalAlpha = 1
            c.beginPath(); c.arc(12, 20, 1, 0, Math.PI * 2); c.fill()
            return
        }
        c.stroke()
    }
}
