pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    required property var tokens
    property string userName: ""
    property string avatarSource: ""
    signal panelsRequested()
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 24
            Item {
                width: parent.width
                height: 72
                Rectangle {
                    id: avatar
                    width: 72
                    height: 72
                    radius: root.tokens.radius.small
                    color: root.tokens.color.surfaceAlt
                    Label {
                        anchors.centerIn: parent
                        visible: portrait.status !== Image.Ready
                        text: (root.userName.trim().charAt(0) || "N").toUpperCase()
                        color: root.tokens.color.accent
                        font.family: root.tokens.type.display.family
                        font.pixelSize: 30
                    }
                    Image {
                        id: portrait
                        anchors { fill: parent; margins: 4 }
                        source: root.avatarSource
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        sourceSize: Qt.size(128, 128)
                    }
                }
                Column {
                    anchors { left: avatar.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    Label { width: parent.width; text: root.userName || "Nayori"; font.pixelSize: 22; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    Label { text: "NayoriOS"; color: root.tokens.color.textMuted; font.pixelSize: 13 }
                }
            }
            Column {
                width: parent.width
                spacing: 8
                Label { text: "Ваше рабочее пространство"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
                Label { width: parent.width; text: "Настройте место для панелей и движение интерфейса."; color: root.tokens.color.textMuted }
            }
            Action { text: "Настроить панели"; selected: true; onClicked: root.panelsRequested() }
        }
