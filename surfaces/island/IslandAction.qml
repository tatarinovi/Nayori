pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
AbstractButton {
    id: root
    required property var tokens
    implicitWidth: Math.max(36, contentItem.implicitWidth + 20)
    implicitHeight: 36
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down ? root.tokens.color.surface : root.hovered ? root.tokens.color.surfaceAlt : Qt.alpha(root.tokens.color.background, 0.28)
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.45)
        opacity: root.enabled ? 1 : 0.35
    }
    contentItem: IslandLabel {
        tokens: root.tokens
        text: root.text; font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.35
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
    }
}
