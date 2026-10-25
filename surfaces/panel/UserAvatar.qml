import QtQuick

// Canvas clipping also works with the software scene graph used for previews.
Canvas {
    id: root
    required property var tokens
    property url source
    property string username: ""
    onSourceChanged: {
        if (String(source)) loadImage(source)
        requestPaint()
    }
    onUsernameChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onImageLoaded: requestPaint()
    Image {
        id: dimensions
        source: root.source
        visible: false
        onStatusChanged: root.requestPaint()
    }
    onPaint: {
        const c = getContext("2d")
        c.reset()
        const radius = root.tokens.radius.medium
        c.beginPath()
        c.roundedRect(0, 0, width, height, radius, radius)
        c.clip()
        c.fillStyle = root.tokens.color.surfaceAlt
        c.fillRect(0, 0, width, height)
        if (String(source) && isImageLoaded(source) && dimensions.status === Image.Ready) {
            const w = dimensions.sourceSize.width
            const h = dimensions.sourceSize.height
            const size = Math.min(w, h)
            if (size > 0)
                c.drawImage(source, (w - size) / 2, (h - size) / 2,
                            size, size, 0, 0, width, height)
        } else {
            c.fillStyle = root.tokens.color.accent
            c.font = "26px " + root.tokens.type.body.family
            c.textAlign = "center"
            c.textBaseline = "middle"
            c.fillText(username.slice(0, 1).toUpperCase(), width / 2, height / 2)
        }
    }
}
