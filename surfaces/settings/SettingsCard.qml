pragma ComponentBehavior: Bound

import QtQuick

// Rounded settings card: display heading, muted subtitle and a column of content.
Rectangle {
    id: card
    required property var tokens
    property string title: ""
    property string subtitle: ""
    property bool highlighted: false
    property int padding: 16
    property alias spacing: body.spacing
    default property alias content: body.data

    width: parent ? parent.width : implicitWidth
    implicitHeight: column.implicitHeight + padding * 2
    radius: tokens.radius.medium
    color: tokens.material.sidebar
    border.width: highlighted ? 2 : 1
    border.color: highlighted ? tokens.color.accent : tokens.color.border

    Column {
        id: column
        x: card.padding
        y: card.padding
        width: parent.width - card.padding * 2
        spacing: 12
        Column {
            visible: card.title.length > 0
            width: parent.width
            spacing: 4
            Text {
                objectName: "settings-card-title"
                width: parent.width
                text: card.title
                color: card.tokens.color.text
                font.family: card.tokens.type.display.family
                font.pixelSize: card.tokens.type.display.size + 2
                font.weight: card.tokens.type.display.weight
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }
            Text {
                visible: card.subtitle.length > 0
                width: parent.width
                text: card.subtitle
                color: card.tokens.color.textMuted
                font.family: card.tokens.type.small.family
                font.pixelSize: card.tokens.type.small.size
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
        }
        Column {
            id: body
            width: parent.width
            spacing: 8
        }
    }
}
