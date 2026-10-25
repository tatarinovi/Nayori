import QtQuick
import Quickshell
import Quickshell.Wayland

// A two-pixel strip at the physical edge bridges the gap to a hidden island.
PanelWindow {
    id: root
    required property string ns
    property bool topEdge: false
    property int side: 0
    property int span: 100
    readonly property bool hovered: edgeHover.hovered
    color: "transparent"
    anchors.top: topEdge
    anchors.bottom: !topEdge
    anchors.left: side < 0
    anchors.right: side > 0
    margins.left: side < 0 ? 24 : 0
    margins.right: side > 0 ? 24 : 0
    implicitWidth: span
    implicitHeight: 2
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: ns
    HoverHandler { id: edgeHover }
}
