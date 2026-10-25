import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool enabled: true
    property string status: "starting"
    signal tapped()
    property Process listener: Process {
        command: ["python3", "-u", Qt.resolvedUrl("super_tap.py").toString().replace("file://", "")]
        running: root.enabled
        stdout: SplitParser {
            onRead: function(line) {
                if (line === "tap") root.tapped()
                else root.status = line
            }
        }
        onExited: {
            if (root.enabled && root.status !== "missing-evdev") {
                root.status = "stopped"
                retry.restart()
            }
        }
    }
    property Timer retry: Timer {
        interval: 3000
        onTriggered: if (root.enabled) root.listener.running = true
    }
}
