pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Левая кнопка и правая кнопка не делят один clicked.
Button {
    id: root

    required property var tokens
    property bool menusOpen: false
    property string iconStyle: "current"
    property string hint: "Пуск"
    // Hit target matches the mark. slotWidth is a little wider so the
    // mark stays inside the cluster's rounded mask. Bar height is unchanged.
    readonly property int glyphSize: 42
    readonly property int slotWidth: glyphSize + 6

    signal contextRequested()
    signal contextReleased()

    padding: 0
    implicitWidth: glyphSize
    implicitHeight: glyphSize
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    clip: false
    Accessible.name: hint
    scale: down && !tokens.motion.off ? 0.96 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.OutCubic
        }
    }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Item {
        clip: false
        NayoriMark {
            variant: root.iconStyle
            anchors.centerIn: parent
            width: root.glyphSize
            height: root.glyphSize
            opacity: !root.enabled ? 0.45
                   : root.iconStyle === "fox" ? 1
                   : (root.down || root.menusOpen) ? 0.72
                   : root.hovered ? 0.84
                   : 1
            ink: !root.enabled ? root.tokens.color.textMuted
                : (root.down || root.checked || root.menusOpen || root.hovered) ? root.tokens.color.accent
                : root.tokens.color.text
            Behavior on opacity {
                NumberAnimation {
                    duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        preventStealing: true
        z: 1
        onPressed: function(mouse) {
            mouse.accepted = true
            root.contextRequested()
        }
        onReleased: function(mouse) {
            mouse.accepted = true
            root.contextReleased()
        }
    }
}
