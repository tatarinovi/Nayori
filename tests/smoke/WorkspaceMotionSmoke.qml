import QtQuick
import Quickshell
import "tokens"
import "islands/workspaces"

ShellRoot {
    id: root
    Tokens { id: theme }
    QtObject {
        id: service
        property bool available: true
        property string focusedOutput: "A"
        property var windows: [{ workspaceId: 1 }]
        property var workspaces: [
            { id: 1, idx: 1, output: "A", active: true },
            { id: 2, idx: 2, output: "A", active: false, urgent: true },
            { id: 3, idx: 3, output: "B", active: true }
        ]
        function focusWorkspace(id) {}
    }
    FloatingWindow {
        visible: true; implicitWidth: 400; implicitHeight: 120
        WorkspacesIsland { id: island; tokens: theme; workspaceService: service }
    }
    property int stage: 0
    property var marker: null
    property real startX: 0
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            if (root.stage === 0) {
                for (let i = 0; i < island.children.length; i++)
                    if (island.children[i].objectName === "workspace-active-marker") root.marker = island.children[i]
                if (!root.marker || island.shown.length !== 2 || island.activeIndex !== 0) throw new Error("initial workspace state")
                root.startX = root.marker.x
                service.workspaces = [{ id: 1, idx: 1, output: "A", active: false }, { id: 2, idx: 2, output: "A", active: true, urgent: true }]
                interval = 60
            } else if (root.stage === 1) {
                if (root.marker.x <= root.startX || root.marker.x >= root.startX + 30) throw new Error("workspace transition")
                interval = 300
            } else if (root.stage === 2) {
                if (Math.abs(root.marker.x - root.startX - 30) > 0.1) throw new Error("workspace transition target")
                theme.animationsEnabled = false
                service.workspaces = [{ id: 1, idx: 1, output: "A", active: true }, { id: 2, idx: 2, output: "A", active: false }]
                if (Math.abs(root.marker.x - root.startX) > 0.1) throw new Error("reduced motion")
                service.workspaces = []
                if (root.marker.visible) throw new Error("empty workspace list")
                console.log("WORKSPACE_MOTION_PASS")
                Qt.quit()
            }
            root.stage++
        }
    }
}
