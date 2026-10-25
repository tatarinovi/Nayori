pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    required property var tokens
        id: button
        property bool selected: false
        property bool navigation: false
        property string detail: ""
        opacity: enabled ? 1 : 0.45
        implicitHeight: Math.max(button.tokens.settings.control, caption.implicitHeight + (detail ? detailCaption.implicitHeight + 4 : 0) + 16)
        implicitWidth: Math.max(120, caption.implicitWidth + 24)
        focusPolicy: Qt.StrongFocus
        Accessible.name: text + (detail ? ", " + detail : "")
        background: Rectangle {
            radius: button.tokens.radius.small
            color: button.down ? button.tokens.color.surface : button.selected || button.hovered ? button.tokens.color.surfaceAlt : "transparent"
            border.width: button.visualFocus || (!button.navigation && !button.selected) ? 1 : 0
            border.color: button.visualFocus ? button.tokens.color.accent : button.tokens.color.border
        }
        contentItem: Item {
            SettingsLabel {
                id: caption
                tokens: button.tokens
                width: parent.width
                anchors { top: button.detail ? parent.top : undefined; verticalCenter: button.detail ? undefined : parent.verticalCenter }
                text: button.text
                leftPadding: 12
                rightPadding: 12
                color: button.selected ? button.tokens.color.accent : button.tokens.color.text
            }
            SettingsLabel {
                id: detailCaption
                objectName: "settings-action-path"
                tokens: button.tokens
                width: parent.width
                anchors { top: caption.bottom; topMargin: 4 }
                visible: !!button.detail
                text: button.detail
                leftPadding: 12
                rightPadding: 12
                font.pixelSize: 12
                color: button.tokens.color.textMuted
            }
        }
    }
