import QtQuick
import QtQuick.Controls
import "../BridgeContext.js" as BridgeContext
AbstractButton {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    property string buttonText: ""
    property string buttonIcon: ""
    property bool leftmost: false
    property bool rightmost: false
    implicitHeight: 32
    text: buttonText
    hoverEnabled: true
    background: Rectangle { radius: 8; color: root.bridge.colorUtils.applyAlpha(root.bridge.irisStyle.text,root.down ? 0.2 : root.hovered ? 0.14 : 0.08) }
    contentItem: Row {
        spacing: 6
        MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: root.buttonIcon; iconSize:16; color:root.bridge.irisStyle.text }
        Text { anchors.verticalCenter: parent.verticalCenter; text:root.buttonText; color:root.bridge.irisStyle.text; font.family:root.bridge.irisStyle.fontMain; font.pixelSize:13 }
    }
}
