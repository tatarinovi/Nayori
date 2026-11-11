import QtQuick
import "../BridgeContext.js" as BridgeContext
Item {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    readonly property string key: "convert-" + String(root)
    property var command: []
    property bool running: false
    signal exited(int exitCode,int exitStatus)
    onRunningChanged: {
        if (!running) return
        if (!bridge.runtime) { running = false; exited(1,0); return }
        bridge.runtime.request("command",{command:command},key)
    }
    Component.onDestruction: if (bridge.runtime) bridge.runtime.release(key)
    Connections {
        target: root.bridge.runtime
        function onResponse(key,data) {
            if (key !== root.key || !root.running) return
            root.running = false
            root.exited(data.exitCode || 0,data.exitStatus || 0)
        }
    }
}
