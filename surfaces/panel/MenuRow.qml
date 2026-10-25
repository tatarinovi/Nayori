pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Текстовая строка меню в том же размере, что и StatusButton.
Button {
    id: root

    required property var tokens
    signal escapePressed()

    padding: 0
    implicitWidth: tokens.panel.control
    implicitHeight: tokens.panel.control
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    scale: down && !tokens.motion.off ? 0.96 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.OutCubic
        }
    }
    Keys.onEscapePressed: function(event) {
        root.escapePressed()
        event.accepted = true
    }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down || root.checked ? root.tokens.color.accentSoft
              : root.hovered ? root.tokens.color.surface : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Text {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: root.text
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
        font.letterSpacing: root.tokens.type.body.letterSpacing
        renderType: Text.NativeRendering
    }
}
