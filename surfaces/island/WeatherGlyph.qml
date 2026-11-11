pragma ComponentBehavior: Bound
import QtQuick

// Line weather marks in the status-button stroke language. The scenic plates stay on the dashboard.
Canvas {
    id: root
    required property var tokens
    property var weatherCode: null
    readonly property string scene: {
        const code = Number(weatherCode)
        if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "storm"
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(code) >= 0) return "snow"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].indexOf(code) >= 0) return "rain"
        if ([143, 248, 260].indexOf(code) >= 0) return "fog"
        if (code === 116) return "partlyCloudy"
        return code === 113 ? "clear" : "cloudy"
    }
    readonly property bool showArtwork: weatherCode !== null && weatherCode !== undefined && String(weatherCode).trim() !== ""
    readonly property color ink: tokens.color.textMuted
    readonly property real dpr: Screen.devicePixelRatio
    implicitWidth: 14
    implicitHeight: 14
    antialiasing: true
    canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
    onSceneChanged: requestPaint()
    onShowArtworkChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onDprChanged: requestPaint()
    Component.onCompleted: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.scale(root.dpr, root.dpr)
        ctx.clearRect(0, 0, width, height)
        if (!root.showArtwork) return
        ctx.strokeStyle = root.ink
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.translate(width / 2, height / 2)
        const scale = Math.min(width, height) / 16
        ctx.scale(scale, scale)
        ctx.lineWidth = 1.5
        if (root.scene === "clear") root.paintClear(ctx)
        else if (root.scene === "partlyCloudy") root.paintPartlyCloudy(ctx)
        else if (root.scene === "cloudy") root.paintCloud(ctx, 0)
        else if (root.scene === "rain") root.paintRain(ctx)
        else if (root.scene === "snow") root.paintSnow(ctx)
        else if (root.scene === "storm") root.paintStorm(ctx)
        else root.paintFog(ctx)
    }

    function paintClear(ctx) {
        ctx.beginPath()
        ctx.arc(0, 0, 2.6, 0, Math.PI * 2)
        const inner = 4.4
        const outer = 6
        for (let i = 0; i < 8; ++i) {
            const angle = i * Math.PI / 4
            ctx.moveTo(Math.cos(angle) * inner, Math.sin(angle) * inner)
            ctx.lineTo(Math.cos(angle) * outer, Math.sin(angle) * outer)
        }
        ctx.stroke()
    }

    function paintPartlyCloudy(ctx) {
        ctx.beginPath()
        ctx.arc(-3, -2.8, 2, Math.PI * 0.85, Math.PI * 1.95)
        for (let i = 3; i <= 6; ++i) {
            const angle = i * Math.PI / 4
            ctx.moveTo(-3 + Math.cos(angle) * 3.5, -2.8 + Math.sin(angle) * 3.5)
            ctx.lineTo(-3 + Math.cos(angle) * 4.5, -2.8 + Math.sin(angle) * 4.5)
        }
        ctx.stroke()
        root.paintCloud(ctx, 1)
    }

    function paintCloud(ctx, dy) {
        ctx.beginPath()
        ctx.moveTo(-4, 2.5 + dy)
        ctx.bezierCurveTo(-7, 2.5 + dy, -7, -1.5 + dy, -4.2, -1.8 + dy)
        ctx.bezierCurveTo(-4, -5.5 + dy, 1.6, -5.8 + dy, 2.5, -2.2 + dy)
        ctx.bezierCurveTo(6.5, -3 + dy, 7, 2.5 + dy, 3.5, 2.5 + dy)
        ctx.closePath()
        ctx.stroke()
    }

    function paintRain(ctx) {
        root.paintCloud(ctx, -1)
        ctx.beginPath()
        ctx.moveTo(-2.7, 3.5)
        ctx.lineTo(-3.7, 5.5)
        ctx.moveTo(2.2, 3.5)
        ctx.lineTo(1.2, 5.5)
        ctx.stroke()
    }

    function paintSnow(ctx) {
        ctx.beginPath()
        const reach = 5.5
        for (let i = 0; i < 3; ++i) {
            const angle = i * Math.PI / 3 - Math.PI / 2
            ctx.moveTo(Math.cos(angle) * reach, Math.sin(angle) * reach)
            ctx.lineTo(-Math.cos(angle) * reach, -Math.sin(angle) * reach)
            for (let sign of [-1, 1]) {
                const tipX = sign * Math.cos(angle) * 3.4
                const tipY = sign * Math.sin(angle) * 3.4
                for (let side of [-1, 1]) {
                    ctx.moveTo(sign * Math.cos(angle) * 1.8 + side * Math.sin(angle) * 1.4,
                               sign * Math.sin(angle) * 1.8 - side * Math.cos(angle) * 1.4)
                    ctx.lineTo(tipX, tipY)
                }
            }
        }
        ctx.stroke()
    }

    function paintStorm(ctx) {
        root.paintCloud(ctx, -1.5)
        ctx.beginPath()
        ctx.moveTo(1.2, 1.8)
        ctx.lineTo(-1.8, 4)
        ctx.lineTo(0.8, 4)
        ctx.lineTo(-1.2, 6.5)
        ctx.stroke()
    }

    function paintFog(ctx) {
        root.paintCloud(ctx, -1.5)
        ctx.beginPath()
        ctx.moveTo(-5, 3.5)
        ctx.lineTo(3, 3.5)
        ctx.moveTo(-3, 6)
        ctx.lineTo(5, 6)
        ctx.stroke()
    }
}
