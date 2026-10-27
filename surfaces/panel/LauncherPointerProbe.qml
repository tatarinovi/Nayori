pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Mapping a transparent surface gives us Wayland's pointer enter on this output.
PanelWindow {
    id: root
    signal located(var output)
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-launcher-pointer-probe"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: if (containsMouse) root.located(root.screen)
        onPositionChanged: root.located(root.screen)
    }
}
