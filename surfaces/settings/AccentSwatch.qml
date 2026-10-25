pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    id: swatch
    required property var tokens
    property color fill: "#C0AFD1"
    property bool marked: false
    property string hex: ""
    padding: 0
    implicitWidth: 44
    implicitHeight: 44
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Accessible.name: hex !== "" ? hex : "Цвет"
    background: Rectangle {
        radius: swatch.tokens.radius.small
        color: swatch.fill
        border.width: swatch.marked ? 2 : 1
        border.color: swatch.marked || swatch.visualFocus || swatch.hovered ? swatch.tokens.color.text : swatch.tokens.color.border
    }
    contentItem: Text {
        visible: swatch.marked
        text: "✓"
        color: swatch.tokens.color.accentText
        font.family: swatch.tokens.type.body.family
        font.pixelSize: swatch.tokens.settings.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
    }
}
