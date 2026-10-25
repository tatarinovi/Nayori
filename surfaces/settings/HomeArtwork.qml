import QtQuick

// Read-only cropped preview; never changes WallpaperManager state.
Canvas {
    id: root
    property url source
    property real cornerRadius: 12
    onSourceChanged: {
        if (String(source)) loadImage(source)
        requestPaint()
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
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
        if (!width || !height || dimensions.status !== Image.Ready || !isImageLoaded(source)) return
        const iw = dimensions.sourceSize.width
        const ih = dimensions.sourceSize.height
        if (iw <= 0 || ih <= 0) return
        const scale = Math.max(width / iw, height / ih)
        const sw = width / scale
        const sh = height / scale
        c.beginPath()
        c.roundedRect(0, 0, width, height, cornerRadius, cornerRadius)
        c.clip()
        c.drawImage(source, (iw - sw) / 2, (ih - sh) / 2, sw, sh, 0, 0, width, height)
    }
}
