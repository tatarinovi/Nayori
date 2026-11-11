import QtQuick
import QtQuick.Controls
import "../BridgeContext.js" as BridgeContext
ToolTip {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    property string position: "bottom"
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    delay: 500
    visible: extraVisibleCondition && (alternativeVisibleCondition || !!parent && parent.hovered === true)
    contentItem: Text { text:root.text; color:root.bridge.ink; font.family:root.bridge.tokens.type.body.family; font.pixelSize:12 }
    background: Rectangle { radius:8; color:root.bridge.background; border.width:1; border.color:root.bridge.muted }
}
