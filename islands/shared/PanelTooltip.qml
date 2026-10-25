import QtQuick
import Quickshell

// A separate non-interactive surface: a panel's 48 px window cannot clip it.
PopupWindow {
    id: root
    required property var tokens
    required property Item target
    property string text: ""
    property bool hovered: false
    property bool armed: false

    onHoveredChanged: armed = false
    visible: hovered && armed && text.trim() !== "" && target !== null
    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: 10
    color: "transparent"
    grabFocus: false
    implicitWidth: Math.min(300, label.implicitWidth + 26)
    implicitHeight: label.contentHeight + 20
    mask: Region {}

    Timer {
        interval: 450
        running: root.hovered
        onTriggered: root.armed = true
    }
    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.small + 4
        color: root.tokens.color.background
        border.width: 1
        border.color: root.tokens.color.accentSoft
        Text {
            id: label
            x: 13
            y: 10
            width: root.width - 26
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: root.tokens.color.text
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            font.weight: root.tokens.type.small.weight
            lineHeight: root.tokens.type.small.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
        }
    }
}
