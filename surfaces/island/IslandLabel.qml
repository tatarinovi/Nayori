import QtQuick
Text {
    required property var tokens
    color: tokens.color.text
    font.family: tokens.type.body.family
    font.pixelSize: 13
    font.weight: Font.Medium
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    lineHeight: 1.25
}
