pragma ComponentBehavior: Bound
import QtQuick
import "WidgetLayout.js" as WidgetLayout

// One short-lived render at a time, shared by the catalogue cards. The image
// result owns its in-memory URL after the source widget has been unloaded.
Item {
    id: root
    required property var tokens
    property var spec: null
    property string requestKey: ""
    property int generation: 0
    readonly property var box: spec ? WidgetLayout.sizeOf(spec) : ({width: 240, height: 160})
    signal rendered(string key, var result)
    signal renderFailed(string key)
    width: box.width
    height: box.height
    function cancel() { generation++; settle.stop(); deadline.stop(); spec = null; requestKey = "" }
    function request(key, value) {
        cancel()
        requestKey = key
        spec = value
        deadline.restart()
    }
    Loader {
        id: source
        anchors.fill: parent
        active: root.spec !== null
        asynchronous: true
        enabled: false
        sourceComponent: DesktopWidgetFrame {
            tokens: root.tokens
            spec: root.spec
            screenWidth: root.box.width
            screenHeight: root.box.height
        }
        onLoaded: settle.restart()
        onStatusChanged: if (status === Loader.Error) root.renderFailed(root.requestKey)
    }
    Timer {
        id: settle
        interval: 80
        onTriggered: {
            if (!source.item || !root.spec) return
            const epoch = root.generation
            const key = root.requestKey
            const scale = Math.min(1, 280 / root.width, 160 / root.height)
            const accepted = source.item.grabToImage(result => {
                if (epoch !== root.generation) return
                // Unload the actual widget and its clocks before taking another
                // request. Preview images never own a system-data subscription.
                deadline.stop()
                root.spec = null
                if (result && result.url.toString() !== "") root.rendered(key, result)
                else root.renderFailed(key)
            }, Qt.size(Math.max(1, Math.round(root.width * scale)), Math.max(1, Math.round(root.height * scale))))
            if (!accepted) { root.spec = null; root.renderFailed(key) }
        }
    }
    Timer {
        id: deadline
        interval: 3000
        onTriggered: {
            const key = root.requestKey
            root.cancel()
            root.renderFailed(key)
        }
    }
    Component.onDestruction: generation++
}
