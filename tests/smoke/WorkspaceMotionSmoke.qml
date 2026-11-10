import QtQuick
import Quickshell
import "tokens"
import "islands/workspaces"
import "surfaces/settings"
import QtTest as Test

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
        property int requested: -1
        function focusWorkspace(id) { requested = id }
    }
    FloatingWindow {
        visible: true; implicitWidth: 400; implicitHeight: 430
        WorkspacesIsland { id: island; tokens: theme; workspaceService: service; outputName: "A" }
        WorkspacesIsland { id: secondary; tokens: theme; workspaceService: service; outputName: "B"; y: 50; indicatorStyle: island.indicatorStyle }
        WorkspaceStylePicker {
            id: picker; y: 100; width: 360; tokens: theme
            selectedStyle: island.indicatorStyle
            onStyleSelected: style => island.indicatorStyle = style
        }
        Test.TestEvent { id: input }

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
                service.workspaces = Array.from({length: 9}, (_, i) => ({id: i + 1, idx: i + 1, output: i === 8 ? "B" : "A", active: i === 5 || i === 8}))
                interval = 100
            } else if (root.stage >= 3 && root.stage < 9) {
                const style = ["dots", "numbers", "kanji", "greek", "dashes", "icons"][root.stage - 3]
                let button = null
                for (const child of picker.children)
                    if (child.objectName === "workspace-style-" + style) button = child
                if (!button) throw new Error("missing style card " + style)
                button.forceActiveFocus()
                input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                if (island.indicatorStyle !== style || secondary.indicatorStyle !== style || !button.checked) throw new Error("live style selection " + style)
                // Activating the selected card must not clear its selection.
                input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                if (!button.checked) throw new Error("selected card toggled off")
                for (const child of picker.children)
                    if (child.objectName.startsWith("workspace-style-") && child !== button && child.checked) throw new Error("multiple selected cards")
                if (island.shown.length !== 8 || secondary.shown.length !== 1 || island.activeIndex !== 5 || secondary.activeIndex !== 0) throw new Error("output filtering or >5 workspaces")
                if (island.width !== 254) throw new Error("style changed track geometry")
                island.step(1)
                if (service.requested !== 7) throw new Error("workspace stepping")
                island.step(-1)
                if (service.requested !== 5) throw new Error("reverse workspace stepping")
            } else if (root.stage === 9) {
                input.mouseClick(island, 8 + 30 * 6 + 14, 24, Qt.LeftButton, Qt.NoModifier, -1)
                if (service.requested !== 7) throw new Error("workspace mouse click")
                service.available = false
                if (island.shown.length || secondary.shown.length || root.marker.visible) throw new Error("unavailable compositor")
                console.log("WORKSPACE_MOTION_PASS")
                Qt.quit()
            }
            root.stage++
        }
    }
}
