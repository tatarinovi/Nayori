pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    required property var tokens
        id: action
        property bool selected: false
        implicitHeight: 40
        implicitWidth: Math.max(120, caption.implicitWidth + 24)
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        background: Rectangle {
            radius: action.tokens.radius.small
            color: action.down ? action.tokens.color.surface : action.selected || action.hovered ? action.tokens.color.surfaceAlt : "transparent"
            border.width: action.visualFocus ? 1 : 0
            border.color: action.tokens.color.accent
        }
        contentItem: SettingsLabel { tokens: action.tokens;
            id: caption
            text: action.text
            leftPadding: 12
            rightPadding: 12
            verticalAlignment: Text.AlignVCenter
            color: action.selected ? action.tokens.color.accent : action.tokens.color.text
        }
    }
