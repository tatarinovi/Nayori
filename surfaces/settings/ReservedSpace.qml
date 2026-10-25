import QtQuick
import Quickshell
import Quickshell.Wayland

// Invisible layer-shell reservation. Niri computes its usable area from these
// surfaces; the visible bars remain independent overlay windows.
PanelWindow {
    id: root
    property int amount: 0
    property bool topEdge: true
    visible: amount > 0
    anchors.top: topEdge
    anchors.bottom: !topEdge
    anchors.left: true
    anchors.right: true
    implicitHeight: Math.max(1, amount)
    color: "transparent"
    exclusiveZone: amount
    exclusionMode: ExclusionMode.Normal
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: topEdge ? "nayori-reserve-top" : "nayori-reserve-bottom"
}
