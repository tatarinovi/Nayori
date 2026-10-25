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
        return code === 113 ? "clear" : "cloudy"
    }
    readonly property bool showArtwork: weatherCode !== null && weatherCode !== undefined && String(weatherCode).trim() !== ""
    readonly property color ink: tokens.color.textMuted
    readonly property real dpr: Screen.devicePixelRatio
    implicitWidth: 7
    implicitHeight: 12.25
    antialiasing: true
    canvasSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))
    onSceneChanged: requestPaint()
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
        ctx.scale(width / 8, height / 14)
        ctx.lineWidth = 1.25
        if (root.scene === "clear") root.paintClear(ctx)
        else if (root.scene === "cloudy") root.paintCloud(ctx, 0)
        else if (root.scene === "rain") root.paintRain(ctx)
        else if (root.scene === "snow") root.paintSnow(ctx)
        else if (root.scene === "storm") root.paintStorm(ctx)
        else root.paintFog(ctx)
    }

    function paintClear(ctx) {
        ctx.beginPath()
        ctx.arc(0, 0, 1.55, 0, Math.PI * 2)
        const inner = 2.25
        const outer = 3.25
        for (let i = 0; i < 8; ++i) {
            const angle = i * Math.PI / 4
            ctx.moveTo(Math.cos(angle) * inner, Math.sin(angle) * inner)
            ctx.lineTo(Math.cos(angle) * outer, Math.sin(angle) * outer)
        }
        ctx.stroke()
    }

    function paintCloud(ctx, dy) {
        ctx.beginPath()
        ctx.moveTo(-2.45, 1.05 + dy)
        ctx.bezierCurveTo(-3.4, 1.05 + dy, -3.45, -0.25 + dy, -2.4, -0.7 + dy)
        ctx.bezierCurveTo(-2.55, -1.95 + dy, -0.9, -2.55 + dy, -0.15, -1.5 + dy)
        ctx.bezierCurveTo(0.55, -2.6 + dy, 2.4, -2.2 + dy, 2.3, -0.75 + dy)
        ctx.bezierCurveTo(3.4, -0.45 + dy, 3.45, 1.05 + dy, 2.4, 1.05 + dy)
        ctx.closePath()
        ctx.stroke()
    }

    function paintRain(ctx) {
        root.paintCloud(ctx, -1.35)
        ctx.beginPath()
        ctx.moveTo(-1.35, 1.55)
        ctx.lineTo(-1.85, 3.35)
        ctx.moveTo(0.85, 1.45)
        ctx.lineTo(0.35, 3.55)
        ctx.stroke()
    }

    function paintSnow(ctx) {
        ctx.beginPath()
        const reach = 3.15
        for (let i = 0; i < 3; ++i) {
            const angle = i * Math.PI / 3 - Math.PI / 2
            ctx.moveTo(Math.cos(angle) * reach, Math.sin(angle) * reach)
            ctx.lineTo(-Math.cos(angle) * reach, -Math.sin(angle) * reach)
        }
        ctx.stroke()
    }

    function paintStorm(ctx) {
        root.paintCloud(ctx, -2.15)
        ctx.beginPath()
        ctx.moveTo(0.85, -0.15)
        ctx.lineTo(-0.85, 1.55)
        ctx.lineTo(0.15, 1.55)
        ctx.lineTo(-0.55, 3.85)
        ctx.stroke()
    }

    function paintFog(ctx) {
        root.paintCloud(ctx, -1.7)
        ctx.beginPath()
        ctx.moveTo(-2.15, 1.15)
        ctx.lineTo(1.35, 1.15)
        ctx.moveTo(-1.15, 2.45)
        ctx.lineTo(2.15, 2.45)
        ctx.stroke()
    }
}
