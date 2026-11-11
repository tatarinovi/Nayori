import QtQuick
import QtQuick.Controls
import "../BridgeContext.js" as BridgeContext
// The Notes face uses the original round Done control, without other shell skins.
Button {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    property real buttonRadius: 999
    property color colBackground: "transparent"
    property color colBackgroundHover: bridge.surface
    property color colRipple: bridge.accent
    property var downAction: null
    hoverEnabled: true
    onPressed: if (typeof downAction === "function") downAction()
    background: Rectangle { radius:root.buttonRadius; color:root.down ? root.colRipple : root.hovered ? root.colBackgroundHover : root.colBackground }
}
