pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Текстовая строка меню в том же размере, что и StatusButton.
Button {
    id: root

    required property var tokens
    property string subtitle: ""
    property string glyph: ""
    property bool showChevron: true
    signal escapePressed()

    padding: 0
    implicitWidth: tokens.panel.control
    implicitHeight: glyph ? 64 : tokens.panel.control
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
    contentItem: Item {
        Rectangle {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 42
            radius: root.tokens.radius.medium
            color: root.tokens.color.surfaceAlt
            visible: root.glyph !== ""
            MenuGlyph {
                anchors.centerIn: parent
                width: 23; height: 23
                kind: root.glyph
                ink: root.tokens.color.accent
            }
        }
        Column {
            x: root.glyph ? 68 : 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (root.glyph && root.showChevron ? 34 : 10)
            spacing: 4
            Text {
                width: parent.width
                text: root.text
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.down || root.checked ? root.tokens.color.accentSoftText : root.tokens.color.text
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.type.body.size
                font.weight: root.tokens.type.body.weight
            }
            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.tokens.color.textMuted
                font.family: root.tokens.type.small.family
                font.pixelSize: root.tokens.type.small.size
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== "" && root.showChevron
            text: "›"
            color: root.tokens.color.accent
            font.pixelSize: 24
        }
    }
}
