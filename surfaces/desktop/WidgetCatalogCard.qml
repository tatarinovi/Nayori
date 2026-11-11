pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var tokens
    required property var entry
    property var snapshot: null
    readonly property int previewHeight: Math.min(112, Math.round(width * 0.55))
    objectName: "widget-catalog-card-" + entry.id + "-" + entry.size
    height: previewHeight + 66
    hoverEnabled: true
    Accessible.name: "Добавить: " + entry.name + ", " + entry.category
    background: Rectangle {
        radius: root.tokens.radius.medium
        color: root.tokens.material.sidebar
        border.width: root.hovered || root.visualFocus ? 2 : 1
        border.color: root.hovered || root.visualFocus ? root.tokens.color.accent : root.tokens.color.border
    }
    contentItem: Item {
        Item {
            x: 8; y: 8
            width: parent.width - 16; height: root.previewHeight - 8
            Image {
                anchors.fill: parent
                source: root.snapshot ? root.snapshot.url : ""
                fillMode: Image.PreserveAspectFit
            }
            Text {
                anchors.centerIn: parent
                visible: !root.snapshot
                text: root.entry.icon || "◈"
                color: root.tokens.color.textMuted
                font.pixelSize: 30
            }
        }
        Text {
            x: 10; y: root.previewHeight + 7
            width: parent.width - 20
            text: root.entry.name
            color: root.tokens.color.text
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 10
            anchors.right: plus.left; anchors.rightMargin: 6
            anchors.bottom: parent.bottom; anchors.bottomMargin: 9
            text: root.entry.category
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        Text {
            id: plus
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
            text: "+"
            color: root.tokens.color.accent
            font.pixelSize: 21
        }
    }
}
