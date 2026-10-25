pragma ComponentBehavior: Bound

import QtQuick

// Quiet note with an (i) glyph. Not interactive.
Rectangle {
    id: row
    required property var tokens
    property string text: ""
    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(36, message.implicitHeight + 20)
    radius: tokens.radius.small + 2
    color: Qt.alpha(tokens.color.text, 0.04)
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    SettingsNavGlyph {
        id: glyph
        name: "about"
        width: 16; height: 16
        ink: row.tokens.color.textMuted
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
    }
    Text {
        id: message
        anchors { left: glyph.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        text: row.text
        color: row.tokens.color.textMuted
        font.family: row.tokens.type.small.family
        font.pixelSize: row.tokens.type.small.size - 1
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        lineHeight: 1.25
    }
}
