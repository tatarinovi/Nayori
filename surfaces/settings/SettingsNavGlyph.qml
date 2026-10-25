import QtQuick

// A compact family of filled, softly rounded silhouettes on the same 24 px grid.
Canvas {
    id: root
    property string name: "home"
    property color ink: "white"
    onInkChanged: requestPaint()
    onNameChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.scale(width / 24, height / 24)
        c.fillStyle = ink
        c.strokeStyle = ink
        c.lineWidth = 2
        c.lineCap = "round"
        c.lineJoin = "round"
        function tile(x, y, w, h, r) {
            c.beginPath()
            c.moveTo(x + r, y)
            c.lineTo(x + w - r, y)
            c.quadraticCurveTo(x + w, y, x + w, y + r)
            c.lineTo(x + w, y + h - r)
            c.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            c.lineTo(x + r, y + h)
            c.quadraticCurveTo(x, y + h, x, y + h - r)
            c.lineTo(x, y + r)
            c.quadraticCurveTo(x, y, x + r, y)
            c.fill()
        }
        function line(x, y, xx, yy) {
            c.beginPath(); c.moveTo(x, y); c.lineTo(xx, yy); c.stroke()
        }
        function hole(x, y, w, h, r) {
            c.globalCompositeOperation = "destination-out"
            tile(x, y, w, h, r)
            c.globalCompositeOperation = "source-over"
        }
        if (name === "home") {
            // Overview: one broad card and two smaller summaries.
            tile(3, 3, 18, 7, 2)
            tile(3, 13, 7, 8, 2)
            tile(13, 13, 8, 8, 2)
        } else if (name === "system") {
            tile(2, 3, 20, 14, 3)
            hole(5, 6, 14, 8, 1)
            tile(10, 17, 4, 3, 1)
            line(7, 21, 17, 21)
        } else if (name === "devices") {
            // Mouse and keyboard, with negative-space details.
            tile(14, 2, 8, 13, 4)
            hole(17.2, 4.5, 1.6, 4, 0.8)
            tile(2, 10, 10, 11, 2)
            hole(4, 13, 6, 1.5, 0.5)
            hole(4, 16, 6, 1.5, 0.5)
        } else if (name === "appearance") {
            // Brush with a separate soft bristle.
            c.beginPath()
            c.moveTo(10, 12); c.lineTo(18, 3)
            c.quadraticCurveTo(20, 1, 22, 3)
            c.quadraticCurveTo(23, 4, 21, 6)
            c.lineTo(13, 15); c.closePath(); c.fill()
            c.beginPath()
            c.moveTo(10, 14)
            c.bezierCurveTo(15, 17, 11, 23, 3, 21)
            c.bezierCurveTo(6, 19, 3, 15, 10, 14)
            c.fill()
        } else if (name === "windows") {
            c.globalAlpha = 0.5
            tile(8, 3, 14, 14, 3)
            c.globalAlpha = 1
            tile(2, 8, 15, 14, 3)
            hole(5, 13, 9, 6, 1)
        } else if (name === "apps") {
            tile(3, 3, 7, 7, 2)
            tile(14, 3, 7, 7, 2)
            tile(3, 14, 7, 7, 2)
            c.beginPath(); c.arc(17.5, 17.5, 3.5, 0, Math.PI * 2); c.fill()
        } else if (name === "wallpapers") {
            tile(2, 3, 20, 18, 3)
            hole(5, 6, 14, 12, 1)
            c.beginPath(); c.moveTo(4, 19); c.lineTo(10, 11); c.lineTo(14, 16); c.lineTo(17, 12); c.lineTo(21, 19); c.fill()
            c.beginPath(); c.arc(16, 8, 1.5, 0, Math.PI * 2); c.fill()
        } else if (name === "panels") {
            tile(2, 15, 20, 6, 3)
            tile(3, 4, 8, 7, 2)
            c.globalAlpha = 0.5; tile(14, 4, 7, 7, 2)
        } else if (name === "island") {
            tile(1, 7, 22, 10, 5)
            hole(4, 10, 3, 4, 1.5); hole(17, 10, 3, 4, 1.5)
        } else if (name === "network") {
            c.lineWidth = 2.5
            for (let r = 6; r <= 11; r += 5) {
                c.beginPath(); c.arc(12, 19, r, Math.PI * 1.23, Math.PI * 1.77); c.stroke()
            }
            c.beginPath(); c.arc(12, 19, 1.8, 0, Math.PI * 2); c.fill()
        } else if (name === "sound") {
            c.lineWidth = 3
            c.beginPath(); c.arc(12, 12, 8, Math.PI, Math.PI * 2); c.stroke()
            tile(2, 11, 5, 10, 2); tile(17, 11, 5, 10, 2)
        } else if (name === "power") {
            tile(2, 6, 18, 13, 3); tile(20, 10, 3, 5, 1)
            hole(5, 9, 12, 7, 1)
        } else {
            // System information: a solid seal and readable inset "i".
            c.beginPath(); c.arc(12, 12, 10, 0, Math.PI * 2); c.fill()
            hole(11, 10, 2, 7, 1)
            hole(11, 6, 2, 2, 1)
        }
    }
}
