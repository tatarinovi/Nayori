import QtQuick
import QtQuick.Controls

Button {
    id: root
    required property var colors
    property bool filled: false
    implicitHeight: 44
    implicitWidth: 120
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        font.family: "Inter"
        font.pixelSize: 14
        font.weight: root.filled ? Font.DemiBold : Font.Medium
        color: root.filled ? root.colors.accentText : root.colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        opacity: root.enabled ? 1 : 0.45
    }
    background: Rectangle {
        radius: 10
        color: root.filled ? root.colors.accent : root.hovered || root.down ? root.colors.surfaceAlt : "transparent"
        opacity: root.enabled ? (root.down ? 0.75 : 1) : 0.45
        border.width: root.visualFocus ? 2 : root.filled ? 0 : 1
        border.color: root.visualFocus ? root.colors.text : root.colors.border
    }
}
