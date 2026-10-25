pragma ComponentBehavior: Bound

import QtQuick

Text {
    id: root
    required property var tokens
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.settings.body
        font.weight: root.tokens.type.body.weight
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }
