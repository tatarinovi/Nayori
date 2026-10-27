import QtQuick

// Same rounded-square crop on the desktop, lock screen and SDDM.
Canvas {
    id: root
    required property var colors
    property url source
    property string username: ""
    property real cornerRadius: 12
    property string fontFamily: "Inter"
    readonly property color surfaceColor: colors.surfaceAlt
    readonly property color initialColor: colors.accent
    onSurfaceColorChanged: requestPaint()
    onInitialColorChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onSourceChanged: {
        if (String(source)) loadImage(source)
        requestPaint()
    }
    onUsernameChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onImageLoaded: requestPaint()
    Image { id: dimensions; source: root.source; visible: false; onStatusChanged: root.requestPaint() }
    onPaint: {
        const c = getContext("2d")
        c.reset()
        c.beginPath()
        c.roundedRect(0, 0, width, height, cornerRadius, cornerRadius)
        c.clip()
        c.fillStyle = surfaceColor
        c.fillRect(0, 0, width, height)
        if (String(source) && isImageLoaded(source) && dimensions.status === Image.Ready) {
            const w = dimensions.sourceSize.width
            const h = dimensions.sourceSize.height
            const size = Math.min(w, h)
            if (size > 0) c.drawImage(source, (w - size) / 2, (h - size) / 2, size, size, 0, 0, width, height)
        } else {
            c.fillStyle = initialColor
            c.font = "26px " + fontFamily
            c.textAlign = "center"
            c.textBaseline = "middle"
            c.fillText(username.slice(0, 1).toUpperCase(), width / 2, height / 2)
        }
    }
}
