pragma ComponentBehavior: Bound
import QtQuick

Text {
    id: root
    required property var tokens
    property bool muted: false
    property bool display: false
    color: muted ? tokens.color.textMuted : tokens.color.text
    font.family: display ? tokens.type.display.family : tokens.type.body.family
    font.pixelSize: display ? tokens.type.display.size : tokens.type.body.size
    font.weight: display ? tokens.type.display.weight : tokens.type.body.weight
    font.letterSpacing: display ? tokens.type.display.letterSpacing : tokens.type.body.letterSpacing
    lineHeight: display ? tokens.type.display.lineHeight : tokens.type.body.lineHeight
    textFormat: Text.PlainText
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
}
