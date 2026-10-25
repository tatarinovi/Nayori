import QtQuick

Canvas {
    id: root
    property string kind: ""
    required property color ink
    implicitWidth: 24
    implicitHeight: 24
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset(); c.scale(width / 24, height / 24)
        c.strokeStyle = ink; c.lineWidth = 1.7
        c.lineCap = "round"; c.lineJoin = "round"; c.beginPath()
        if (kind === "apps") {
            for (let x = 4; x < 20; x += 10)
                for (let y = 4; y < 20; y += 10) c.roundedRect(x, y, 6, 6, 1.5, 1.5)
        } else if (kind === "terminal") {
            c.moveTo(4, 6); c.lineTo(10, 12); c.lineTo(4, 18)
            c.moveTo(13, 18); c.lineTo(20, 18)
        } else if (kind === "folder") {
            c.moveTo(3, 7); c.lineTo(3, 4); c.lineTo(10, 4); c.lineTo(12, 7)
            c.lineTo(21, 7); c.lineTo(21, 20); c.lineTo(3, 20); c.closePath()
            c.moveTo(3, 9); c.lineTo(21, 9)
        } else if (kind === "settings") {
            c.arc(12, 12, 6.5, 0, Math.PI * 2)
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4
                c.moveTo(12 + Math.cos(a) * 7, 12 + Math.sin(a) * 7)
                c.lineTo(12 + Math.cos(a) * 9, 12 + Math.sin(a) * 9)
            }
            c.moveTo(15, 12); c.arc(12, 12, 3, 0, Math.PI * 2)
        } else if (kind === "back") {
            c.moveTo(14, 5); c.lineTo(7, 12); c.lineTo(14, 19)
            c.moveTo(7, 12); c.lineTo(21, 12)
        } else if (kind === "lock") {
            c.roundedRect(5, 10, 14, 11, 2, 2)
            c.moveTo(8, 10); c.lineTo(8, 7)
            c.arc(12, 7, 4, Math.PI, Math.PI * 2)
            c.lineTo(16, 10)
            c.moveTo(12, 14); c.lineTo(12, 17)
        } else if (kind === "logout") {
            c.moveTo(10, 3); c.lineTo(4, 3); c.lineTo(4, 21); c.lineTo(10, 21)
            c.moveTo(10, 12); c.lineTo(21, 12)
            c.moveTo(16, 7); c.lineTo(21, 12); c.lineTo(16, 17)
        } else if (kind === "reboot") {
            c.arc(12, 12, 8, -0.7, Math.PI * 1.6)
            c.moveTo(20, 4); c.lineTo(20, 9); c.lineTo(15, 9)
        } else if (kind === "power") {
            c.arc(12, 13, 8, -Math.PI * 0.3, Math.PI * 1.3)
            c.moveTo(12, 2); c.lineTo(12, 12)
        }
        c.stroke()
    }
}
