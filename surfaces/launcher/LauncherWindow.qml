pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Created only while open: the keyboard and pointer return to the desktop on close.
PanelWindow {
    id: root
    required property var tokens
    signal closeRequested()

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: function(mouse) {
            if (mouse.x < launcher.x || mouse.x > launcher.x + launcher.width
                    || mouse.y < launcher.y || mouse.y > launcher.y + launcher.height)
                root.closeRequested()
        }
        onWheel: function(wheel) { wheel.accepted = true }
    }

    Launcher {
        id: launcher
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64 + root.tokens.spacing.small
        panelWidth: Math.min(560, Math.max(1, parent.width - root.tokens.spacing.large * 2))
        onCloseRequested: root.closeRequested()
        Component.onCompleted: open()
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(launcher.focusInput)
    }
}
