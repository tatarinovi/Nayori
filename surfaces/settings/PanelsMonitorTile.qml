pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Monitor picker tile: wallpaper preview (when known), output name and the primary badge.
AbstractButton {
    id: tile
    required property var tokens
    property string outputName: ""
    property bool primary: false
    property bool selected: false
    property url source: ""
    signal focusReceived()

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitWidth: 200
    implicitHeight: 84
    Accessible.role: Accessible.RadioButton
    Accessible.name: outputName + (primary ? ", основной" : "")
    Accessible.checked: selected
    onActiveFocusChanged: if (activeFocus) focusReceived()

    background: Item {
        SettingsRoundClip {
            anchors.fill: parent
            radius: tile.tokens.radius.small + 4
            Rectangle { anchors.fill: parent; color: tile.tokens.color.surfaceAlt }
            Image {
                anchors.fill: parent
                visible: status === Image.Ready
                source: tile.source
                sourceSize: Qt.size(400, 240)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            Rectangle { anchors.fill: parent; color: Qt.alpha(tile.tokens.color.background, 0.6) }
        }
        Rectangle {
            anchors.fill: parent
            radius: tile.tokens.radius.small + 4
            color: "transparent"
            border.width: tile.selected || tile.visualFocus ? 2 : 1
            border.color: tile.selected || tile.visualFocus ? tile.tokens.color.accent
                : tile.hovered ? tile.tokens.color.accentSoft : tile.tokens.color.border
        }
    }
    contentItem: Item {
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: tile.primary ? -8 : 0 }
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            text: tile.outputName
            elide: Text.ElideRight
            color: tile.tokens.color.text
            font.family: tile.tokens.type.body.family
            font.pixelSize: tile.tokens.type.small.size
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
        }
        Rectangle {
            visible: tile.primary
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
            width: badge.implicitWidth + 16
            height: 20
            radius: height / 2
            color: Qt.alpha(tile.tokens.color.background, 0.7)
            border.width: 1
            border.color: tile.tokens.color.border
            Text {
                id: badge
                anchors.centerIn: parent
                text: "Основной"
                color: tile.tokens.color.text
                font.family: tile.tokens.type.small.family
                font.pixelSize: tile.tokens.type.small.size - 2
                textFormat: Text.PlainText
            }
        }
    }
}
