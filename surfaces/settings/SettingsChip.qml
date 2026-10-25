pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Small checkable pill, accent-filled while on.
AbstractButton {
    id: chip
    required property var tokens
    signal focusReceived()
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 32
    implicitWidth: label.implicitWidth + 28
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked
    onActiveFocusChanged: if (activeFocus) focusReceived()
    contentItem: Text {
        id: label
        text: chip.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: chip.checked ? chip.tokens.color.accentText : chip.tokens.color.text
        font.family: chip.tokens.type.body.family
        font.pixelSize: chip.tokens.type.small.size - 1
        font.weight: chip.checked ? Font.DemiBold : chip.tokens.type.body.weight
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: height / 2
        color: chip.checked
            ? (chip.down ? chip.tokens.color.accentSoft : chip.tokens.color.accent)
            : (chip.hovered ? chip.tokens.color.surfaceAlt : "transparent")
        border.width: chip.checked && !chip.visualFocus ? 0 : 1
        border.color: chip.visualFocus ? chip.tokens.color.accent
            : chip.hovered ? chip.tokens.color.accentSoft : chip.tokens.color.border
    }
}
