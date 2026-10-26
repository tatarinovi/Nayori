pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Button {
    id: root
    required property var tokens
    property bool primary: false
    property bool quiet: false
    property string glyph: ""
    implicitWidth: Math.max(32, label.implicitWidth + 24)
    implicitHeight: 34
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    contentItem: ClipboardLabel {
        id: label
        tokens: root.tokens
        text: root.text
        visible: root.glyph === ""
        font.pixelSize: 12
        color: root.primary ? root.tokens.color.accentText : root.tokens.color.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.5
    }
    ClipboardGlyph {
        anchors.centerIn: parent
        visible: root.glyph !== ""
        name: root.glyph
        ink: root.tokens.color.text
        opacity: root.enabled ? 1 : 0.5
    }
    background: Rectangle {
        radius: root.quiet ? root.tokens.radius.capsule : root.tokens.radius.small
        color: root.primary ? (root.down ? root.tokens.color.accentSoft : root.tokens.color.accent)
            : root.checked || root.down ? root.tokens.color.surfaceAlt
            : root.hovered ? Qt.alpha(root.tokens.color.surfaceAlt, 0.6) : "transparent"
        border.width: root.visualFocus || (!root.quiet && !root.primary) ? 1 : 0
        border.color: root.visualFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.65)
        opacity: root.enabled ? 1 : 0.5
    }
}
