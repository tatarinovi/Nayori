pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

TextField {
    id: field
    required property var tokens
    width: parent ? parent.width : implicitWidth
    height: 44
    selectByMouse: true
    color: tokens.color.text
    placeholderTextColor: tokens.color.textMuted
    selectionColor: tokens.color.accent
    selectedTextColor: tokens.color.accentText
    font.family: tokens.type.body.family
    font.pixelSize: tokens.settings.body
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        radius: field.tokens.radius.small
        color: field.tokens.color.surfaceAlt
        border.width: 1
        border.color: field.activeFocus ? field.tokens.color.accent : field.tokens.color.border
    }
}
