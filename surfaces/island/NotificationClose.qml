import QtQuick
import QtQuick.Controls

// Кнопка «×» в строке уведомления: убирает одно уведомление. Hit-область больше значка.
AbstractButton {
    id: root
    required property var tokens
    implicitWidth: 28
    implicitHeight: 28
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Убрать уведомление"
    background: Rectangle {
        radius: width / 2
        color: root.down ? root.tokens.color.surface : root.hovered ? root.tokens.color.surfaceAlt : "transparent"
        border.width: root.visualFocus ? 2 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Item {
        Glyph {
            anchors.centerIn: parent
            width: 14; height: 14
            name: "close"
            ink: root.hovered ? root.tokens.color.text : root.tokens.color.textMuted
        }
    }
}
