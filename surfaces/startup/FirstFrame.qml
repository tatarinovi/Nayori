import QtQuick
import QtQuick.Window as Native

// Observe the actual QQuickWindow, not the Quickshell window proxy. A queued
// callback keeps all readiness mutations on the GUI thread after submission.
Item {
    id: root
    property bool armed: false
    property bool seen: false
    property int generation: 0
    readonly property var renderWindow: root.Native.Window.window
    onArmedChanged: {
        generation++
        seen = false
        requestFrame()
    }
    onRenderWindowChanged: { generation++; seen = false; requestFrame() }
    Component.onCompleted: requestFrame()
    function requestFrame() {
        if (armed && renderWindow) renderWindow.update()
    }
    Connections {
        target: root.renderWindow
        enabled: root.armed && !root.seen
        function onFrameSwapped() {
            const ticket = root.generation
            Qt.callLater(function() {
                if (ticket === root.generation && root.armed && root.renderWindow) root.seen = true
            })
        }
    }
}
