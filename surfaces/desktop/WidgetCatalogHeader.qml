pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var tokens
    property int count: 0
    property bool expanded: false
    property bool nested: false
    height: nested ? 40 : 44
    hoverEnabled: true
    Accessible.name: text + ", " + count
    Accessible.description: expanded ? "Свернуть список" : "Развернуть список"
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.hovered || root.visualFocus ? root.tokens.color.surfaceAlt : root.nested ? "transparent" : root.tokens.material.sidebar
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Item {
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.right: countLabel.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.nested ? Font.Medium : Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            id: countLabel
            anchors.right: arrow.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
        }
        Text {
            id: arrow
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.expanded ? "⌄" : "›"
            color: root.tokens.color.textMuted
            font.pixelSize: 20
        }
    }
}
