pragma ComponentBehavior: Bound
import QtQuick
import "../../services/island/NotificationList.js" as List

// Картинка уведомления (аватар, миниатюра скриншота) или значок источника.
// Скругление рисуется на Canvas: оно работает и при программном рендеринге.
Item {
    id: root
    required property var tokens
    property var record: ({})
    // Высота; ширина у широких миниатюр больше.
    property int size: 56
    readonly property string imageSource: {
        const s = String(record.image || "")
        if (!s) return ""
        return s.indexOf("/") === 0 ? "file://" + s : s
    }
    readonly property bool hasImage: imageSource !== "" && probe.status === Image.Ready && probe.implicitWidth > 0 && probe.implicitHeight > 0
    readonly property real ratio: hasImage ? probe.implicitWidth / probe.implicitHeight : 1
    readonly property bool wide: hasImage && ratio > 1.25
    // «1920 × 1080» для миниатюр скриншотов; у аватаров подписи нет.
    readonly property string caption: hasImage ? List.imageCaption(probe.implicitWidth, probe.implicitHeight) : ""
    implicitHeight: size
    implicitWidth: hasImage && wide ? Math.round(Math.min(size * 2.4, size * ratio)) : size
    width: implicitWidth
    height: implicitHeight

    // Исходные размеры нужны для пропорций и подписи; сама картинка рисуется на Canvas.
    Image {
        id: probe
        source: root.imageSource
        visible: false
        asynchronous: true
        onStatusChanged: if (status === Image.Ready) canvas.load()
    }
    NotificationIcon {
        visible: !root.hasImage
        anchors.fill: parent
        tokens: root.tokens
        record: root.record
        size: root.size
    }
    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.hasImage
        property color edge: Qt.alpha(root.tokens.color.border, 0.9)
        property bool round: !root.wide
        onEdgeChanged: requestPaint()
        onRoundChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onImageLoaded: requestPaint()
        function load() { if (root.imageSource) loadImage(root.imageSource) }
        Component.onCompleted: load()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            if (!root.hasImage || !isImageLoaded(root.imageSource)) return
            const r = round ? Math.min(width, height) / 2 : Math.min(8, height / 4)
            c.save()
            c.beginPath(); c.roundedRect(0.5, 0.5, width - 1, height - 1, r, r); c.clip()
            // Обрезка по центру, как fillMode: PreserveAspectCrop.
            const iw = probe.implicitWidth, ih = probe.implicitHeight
            const scale = Math.max(width / iw, height / ih)
            const sw = width / scale, sh = height / scale
            c.drawImage(root.imageSource, (iw - sw) / 2, (ih - sh) / 2, sw, sh, 0, 0, width, height)
            c.restore()
            c.strokeStyle = edge; c.lineWidth = 1
            c.beginPath(); c.roundedRect(0.5, 0.5, width - 1, height - 1, r, r); c.stroke()
        }
    }
}
