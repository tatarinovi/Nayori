import QtQuick

Text {
    required property var tokens
    color: tokens.color.text
    font.family: tokens.type.body.family
    font.pixelSize: tokens.type.body.size
    font.weight: tokens.type.body.weight
    textFormat: Text.PlainText
    elide: Text.ElideRight
}
