pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

CheckBox {
    id: toggle
    required property var tokens
    property string description: ""
    signal focusReceived()
    width: parent ? parent.width : implicitWidth
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.description: description
    opacity: enabled ? 1 : 0.45
    spacing: 12
    padding: 12
    onActiveFocusChanged: if (activeFocus) focusReceived()
    background: Rectangle {
        radius: toggle.tokens.radius.small
        color: toggle.tokens.color.surfaceAlt
        border.width: toggle.visualFocus || toggle.hovered ? 1 : 0
        border.color: toggle.tokens.color.accent
    }
    indicator: Rectangle {
        x: toggle.leftPadding
        y: (toggle.height - height) / 2
        width: 20
        height: 20
        radius: 5
        color: toggle.checked ? toggle.tokens.color.accent : toggle.tokens.color.background
        border.width: toggle.checked ? 0 : 1
        border.color: toggle.tokens.color.accentSoft
        Text {
            anchors.centerIn: parent
            text: toggle.checked ? "✓" : ""
            color: toggle.tokens.color.accentText
            font.family: toggle.tokens.type.body.family
            font.pixelSize: toggle.tokens.settings.body
            textFormat: Text.PlainText
        }
    }
    contentItem: Column {
        property real labelIndent: toggle.indicator.width + toggle.spacing
        spacing: 6
        Text {
            width: parent.width
            leftPadding: parent.labelIndent
            text: toggle.text
            color: toggle.tokens.color.text
            font.family: toggle.tokens.type.body.family
            font.pixelSize: toggle.tokens.settings.body
            font.weight: toggle.tokens.type.body.weight
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }
        Text {
            visible: toggle.description.length > 0
            width: parent.width
            leftPadding: parent.labelIndent
            text: toggle.description
            color: toggle.tokens.color.textMuted
            font.family: toggle.tokens.type.small.family
            font.pixelSize: toggle.tokens.type.small.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }
    }
}
