pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    required property var tokens
        id: button
        property bool selected: false
        implicitHeight: button.tokens.settings.control
        implicitWidth: Math.max(120, caption.implicitWidth + 24)
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        background: Rectangle {
            radius: button.tokens.radius.small
            color: button.down ? button.tokens.color.surface : button.selected || button.hovered ? button.tokens.color.surfaceAlt : "transparent"
            border.width: button.visualFocus ? 1 : 0
            border.color: button.tokens.color.accent
        }
        contentItem: SettingsLabel { tokens: button.tokens;
            id: caption
            text: button.text
            leftPadding: 12
            rightPadding: 12
            verticalAlignment: Text.AlignVCenter
            color: button.selected ? button.tokens.color.accent : button.tokens.color.text
        }
    }
