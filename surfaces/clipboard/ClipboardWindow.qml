pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "ClipboardLogic.js" as Logic

// Briefly map transparent windows on every output. Wayland's initial pointer
// enter supplies output-local logical coordinates without reading input devices
// or requiring the user to move the pointer. Freeze that anchor for this opening.
PanelWindow {
    id: root
    required property var tokens
    required property var store
    required property var host
    signal closeRequested()
    signal closeFinished()
    readonly property bool selectedOutput: host.clipboardOutput === screen.name
    readonly property bool showing: selectedOutput && host.clipboardOpened
    property real reveal: 0
    readonly property alias panelContent: panel
    readonly property alias blurBounds: glassRegion
    readonly property int popupWidth: Math.max(1, Math.min(580, root.width - 24))
    readonly property int popupHeight: Math.max(1, Math.min(popupWidth < 480 ? 640 : 520, root.height - 24))
    readonly property int popupX: Logic.placement(host.clipboardAnchor.x, popupWidth, width, 12, 12)
    readonly property int popupY: Logic.placement(host.clipboardAnchor.y, popupHeight, height, 12, 12)
    readonly property bool fromBottom: host.clipboardAnchor.y > popupY + popupHeight / 2
    readonly property int revealedHeight: Math.round(popupHeight * reveal)
    property bool clearFramePending: false
    function queueClearFrame() {
        if (showing || !selectedOutput || host.clipboardOpened) return
        clearFramePending = true
        // Destroy only after the compositor received an empty blur region and
        // a transparent buffer. Otherwise its close animation keeps old blur.
        const window = panel.Window.window
        if (window) window.update()
    }
    onShowingChanged: {
        if (showing) clearFramePending = false
        reveal = showing ? 1 : 0
        if (!showing && reveal === 0) queueClearFrame()
    }
    onRevealChanged: if (reveal === 0) queueClearFrame()
    Connections {
        target: panel.Window.window
        function onFrameSwapped() {
            if (root.clearFramePending && !root.showing && root.revealedHeight === 0) {
                root.clearFramePending = false
                root.closeFinished()
            }
        }
    }
    Behavior on reveal {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    color: "transparent"
    visible: host.clipboardOutput === "" || selectedOutput
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-clipboard"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Region {
        id: glassRegion
        x: revealClip.x; y: revealClip.y
        width: revealClip.width; height: revealClip.height
        radius: Math.min(root.tokens.radius.medium, height / 2)
    }
    BackgroundEffect.blurRegion: root.tokens.frosted && root.selectedOutput && root.revealedHeight > 0 ? glassRegion : null

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onContainsMouseChanged: if (containsMouse && root.host.clipboardOutput === "")
            root.host.locateClipboard(root.screen.name, mouseX, mouseY)
        onPositionChanged: mouse => {
            if (root.host.clipboardOutput === "") root.host.locateClipboard(root.screen.name, mouse.x, mouse.y)
        }
        onClicked: mouse => {
            if (mouse.x < root.popupX || mouse.x > root.popupX + root.popupWidth
                    || mouse.y < root.popupY || mouse.y > root.popupY + root.popupHeight)
                root.closeRequested()
        }
        onWheel: wheel => { wheel.accepted = true }
    }
    Item {
        id: revealClip
        x: root.popupX
        y: root.popupY + (root.fromBottom ? root.popupHeight - height : 0)
        width: root.popupWidth
        height: root.revealedHeight
        clip: true
        ClipboardPanel {
            id: panel
            tokens: root.tokens
            store: root.store
            interactive: root.showing
            enabled: root.showing
            visible: root.selectedOutput
            opacity: root.reveal
            width: root.popupWidth
            height: root.popupHeight
            y: root.fromBottom ? revealClip.height - height : 0
            onVisibleChanged: if (visible) Qt.callLater(focusInput)
            onCloseRequested: root.closeRequested()
        }
    }
    onVisibleChanged: if (visible && selectedOutput) Qt.callLater(panel.focusInput)
}
