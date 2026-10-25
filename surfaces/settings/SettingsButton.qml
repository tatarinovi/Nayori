pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Pill-radius settings button: accent-filled when primary, outlined otherwise.
Button {
    id: button
    required property var tokens
    property bool primary: false
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitHeight: 40
    implicitWidth: label.implicitWidth + 32
    contentItem: Text {
        id: label
        text: button.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: button.primary ? button.tokens.color.accentText : button.tokens.color.text
        font.family: button.tokens.type.body.family
        font.pixelSize: button.tokens.type.small.size
        font.weight: button.primary ? Font.DemiBold : button.tokens.type.body.weight
        textFormat: Text.PlainText
    }
    background: Rectangle {
        radius: button.tokens.radius.small + 4
        color: button.primary
            ? (button.down ? button.tokens.color.accentSoft : button.tokens.color.accent)
            : (button.down ? button.tokens.color.surface : button.hovered ? button.tokens.color.surfaceAlt : "transparent")
        border.width: button.primary && !button.visualFocus ? 0 : 1
        border.color: button.visualFocus ? button.tokens.color.accent
            : button.hovered ? button.tokens.color.accentSoft : button.tokens.color.border
        opacity: button.enabled ? (button.primary && button.hovered && !button.down ? 0.92 : 1) : 0.5
    }
}
