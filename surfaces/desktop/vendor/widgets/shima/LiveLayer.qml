import QtQuick
// Keep original visualizer content in Nayori's existing canvas surface.
Item {
    id: root
    property bool live: false
    property bool allowed: true
    // Upstream pads its separate surface to contain shader overflow. This host
    // stays inside the existing, unclipped canvas; no extra surface is needed.
    property real pad: 0
    property Component content: null
    Loader {
        anchors.fill: parent
        sourceComponent: root.content
        onLoaded: if (item && item.drawing !== undefined) item.drawing = Qt.binding(() => root.live && root.allowed && root.visible)
    }
}
