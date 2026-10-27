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
        } else if (name === "system" || name === "display" || name === "naomi-place") {
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
        } else if (name === "appearance" || name === "naomi-look") {
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
        } else if ((name === "apps" || name === "start")) {
            tile(3, 3, 7, 7, 2)
            tile(14, 3, 7, 7, 2)
            tile(3, 14, 7, 7, 2)
            c.beginPath(); c.arc(17.5, 17.5, 3.5, 0, Math.PI * 2); c.fill()
        } else if (name === "wallpapers") {
            tile(2, 3, 20, 18, 3)
            hole(5, 6, 14, 12, 1)
            c.beginPath(); c.moveTo(4, 19); c.lineTo(10, 11); c.lineTo(14, 16); c.lineTo(17, 12); c.lineTo(21, 19); c.fill()
            c.beginPath(); c.arc(16, 8, 1.5, 0, Math.PI * 2); c.fill()
        } else if (name === "folder") {
            tile(2, 4, 9, 6, 2)
            tile(2, 7, 20, 13, 3)
        } else if (name === "panels") {
            tile(2, 15, 20, 6, 3)
            tile(3, 4, 8, 7, 2)
            c.globalAlpha = 0.5; tile(14, 4, 7, 7, 2)
        } else if (name === "autohide") {
            // Two arrowheads moving apart: an island that slides away.
            c.lineWidth = 1.5
            c.beginPath(); c.moveTo(12, 2.5); c.lineTo(18, 10); c.lineTo(6, 10); c.closePath(); c.fill(); c.stroke()
            c.beginPath(); c.moveTo(12, 21.5); c.lineTo(18, 14); c.lineTo(6, 14); c.closePath(); c.fill(); c.stroke()
        } else if (name === "pointer") {
            c.lineWidth = 1.5
            c.beginPath()
            c.moveTo(5, 3); c.lineTo(5, 19); c.lineTo(9.2, 15.2); c.lineTo(12.4, 21.5)
            c.lineTo(15.4, 20); c.lineTo(12.3, 13.8); c.lineTo(18, 13.8); c.closePath()
            c.fill(); c.stroke()
        } else if (name === "topisland") {
            // A screen with a pill at the top edge.
            tile(2, 3, 20, 18, 3)
            hole(4, 5, 16, 14, 1.5)
            tile(8, 7, 8, 3, 1.5)
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
        } else if (name === "bluetooth") {
            line(10, 2, 10, 22); line(10, 2, 18, 8); line(18, 8, 5, 18)
            line(10, 22, 18, 16); line(18, 16, 5, 6)
        } else if (name === "mouse") {
            tile(5, 2, 14, 20, 7); hole(11, 5, 2, 6, 1)
        } else if (name === "keyboard" || name === "shortcuts") {
            tile(1, 5, 22, 15, 3)
            for (let row = 0; row < 2; row++)
                for (let key = 0; key < 5; key++) hole(4 + key * 3.2, 8 + row * 4, 1.8, 1.8, 0.4)
            hole(7, 16, 10, 1.5, 0.5)
            if (name === "shortcuts") { c.globalAlpha = 0.5; tile(17, 1, 5, 5, 1) }
        } else if (name === "lockscreen") {
            c.lineWidth = 3
            c.beginPath(); c.arc(12, 9, 5, Math.PI, Math.PI * 2); c.stroke()
            tile(4, 9, 16, 13, 3); hole(11, 13, 2, 5, 1)
        } else if (name === "weather") {
            c.beginPath(); c.arc(7, 7, 4, 0, Math.PI * 2); c.fill()
            c.globalAlpha = 0.6
            tile(3, 12, 19, 8, 4)
            c.beginPath(); c.arc(13, 12, 6, 0, Math.PI * 2); c.fill()
        } else if (name === "workspaces") {
            tile(1, 5, 6, 14, 2); tile(9, 5, 6, 14, 2)
            c.globalAlpha = 0.5; tile(17, 5, 6, 14, 2)
        } else if (name === "localsend" || name === "alttab") {
            line(3, 7, 21, 7); line(17, 3, 21, 7); line(21, 7, 17, 11)
            line(21, 17, 3, 17); line(7, 13, 3, 17); line(3, 17, 7, 21)
            if (name === "alttab") { c.globalAlpha = 0.4; tile(9, 10, 6, 4, 1) }
        } else if (name === "defaults") {
            tile(3, 3, 18, 18, 3)
            c.globalCompositeOperation = "destination-out"
            line(7, 12, 11, 16); line(11, 16, 18, 8)
            c.globalCompositeOperation = "source-over"
        } else if (name === "autostart") {
            c.beginPath(); c.moveTo(7, 3); c.lineTo(21, 12); c.lineTo(7, 21); c.closePath(); c.fill()
            line(3, 4, 3, 20)
        } else if (name === "naomi") {
            // Ears, head, and a short body.
            c.beginPath(); c.moveTo(6.2, 9); c.lineTo(4.2, 2.2); c.lineTo(10.2, 7.2); c.closePath(); c.fill()
            c.beginPath(); c.moveTo(17.8, 9); c.lineTo(19.8, 2.2); c.lineTo(13.8, 7.2); c.closePath(); c.fill()
            c.beginPath(); c.arc(12, 11.2, 4.6, 0, Math.PI * 2); c.fill()
            tile(7.5, 15.2, 9, 6.4, 3)
        } else if (name === "integrations") {
            c.beginPath(); c.arc(7, 12, 3.2, 0, Math.PI * 2); c.stroke()
            c.beginPath(); c.arc(17, 12, 3.2, 0, Math.PI * 2); c.stroke()
            line(10.2, 12, 13.8, 12)
        } else if (name === "updates") {
            c.beginPath(); c.arc(12, 12, 9, Math.PI * 0.1, Math.PI * 1.8); c.stroke()
            line(12, 5, 12, 17); line(8, 13, 12, 17); line(12, 17, 16, 13)
        } else {
            // System information: a solid seal and readable inset "i".
            c.beginPath(); c.arc(12, 12, 10, 0, Math.PI * 2); c.fill()
            hole(11, 10, 2, 7, 1)
            hole(11, 6, 2, 2, 1)
        }
    }
}
