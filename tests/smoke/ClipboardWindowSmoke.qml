pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "tokens"
import "surfaces/clipboard"

// No clipboard service: this fixture cannot read or change the real selection.
ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: true; surfaceStyle: "frosted" }
    FloatingWindow {
        visible: true
        implicitWidth: 420; implicitHeight: 160
        TextArea {
            anchors.fill: parent
            focus: true
            onTextChanged: if (text === "Nayori isolated paste fixture") console.log("CLIPBOARD_PASTE_TARGET_PASS")
        }
    }
    property bool opened: false
    readonly property bool clipboardOpened: opened
    property bool clipboardPresenting: false
    property var shownWindow: null
    property int created: 0
    property string clipboardOutput: ""
    property point clipboardAnchor: Qt.point(0, 0)
    QtObject {
        id: fixture
        property bool ready: true
        property bool copying: false
        property string error: ""
        property var records: []
        signal copied(string identity)
        function copy(identity) {}
        function pin(identity) {}
        function remove(identity) {}
    }
    function locateClipboard(output, x, y) {
        if (!opened || clipboardOutput !== "") return
        clipboardAnchor = Qt.point(x, y)
        clipboardOutput = output
        console.log("CLIPBOARD_WINDOW_ANCHOR", x, y)
    }
    IpcHandler {
        target: "clipboard_test"
        function toggle(): void {
            if (root.opened) root.opened = false
            else if (root.clipboardPresenting) root.opened = true
            else {
                root.clipboardOutput = ""
                root.clipboardPresenting = true
                root.opened = true
                fallback.restart()
            }
        }
        function reduce(): void { theme.animationsEnabled = false }
        function state(): string {
            return JSON.stringify({created:root.created, presenting:root.clipboardPresenting, opened:root.opened,
                reveal:root.shownWindow ? root.shownWindow.reveal : 0,
                focused:root.shownWindow ? root.shownWindow.panelContent.searchInput.activeFocus : false,
                x:root.shownWindow ? root.shownWindow.popupX : 0,
                y:root.shownWindow ? root.shownWindow.popupY : 0,
                blurHeight:root.shownWindow ? root.shownWindow.blurBounds.height : 0,
                fullHeight:root.shownWindow ? root.shownWindow.popupHeight : 0})
        }
    }
    Timer {
        id: fallback
        interval: 250
        onTriggered: if (root.opened && root.clipboardOutput === "" && Quickshell.screens.length)
            root.locateClipboard(Quickshell.screens[0].name, 300, 200)
    }
    Variants {
        model: root.clipboardPresenting ? Quickshell.screens : []
        ClipboardWindow {
            id: surface
            required property var modelData
            screen: modelData
            tokens: theme
            store: fixture
            host: root
            onCloseRequested: root.opened = false
            onCloseFinished: if (!root.opened) {
                if (surface.blurBounds.height !== 0) throw new Error("Blur survived the final frame")
                console.log("CLIPBOARD_CLEAR_FRAME_PASS")
                root.clipboardPresenting = false
            }
            Component.onCompleted: { root.shownWindow = surface; root.created++ }
            Component.onDestruction: if (root.shownWindow === surface) root.shownWindow = null
        }
    }
}
