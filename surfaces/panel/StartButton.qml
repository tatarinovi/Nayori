pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../islands/shared"

// Левая кнопка и правая кнопка не делят один clicked.
Button {
    id: root

    required property var tokens
    property bool menusOpen: false
    property string iconStyle: "current"
    property string hint: "Пуск"

    signal contextRequested()
    signal contextReleased()

    padding: 0
    implicitWidth: tokens.panel.control
    implicitHeight: tokens.panel.control
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint
    scale: down && !tokens.motion.off ? 0.96 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.OutCubic
        }
    }
    PanelTooltip {
        tokens: root.tokens
        target: root
        hovered: root.hovered && !root.down && !root.menusOpen
        text: root.hint
    }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down || root.checked || root.menusOpen ? root.tokens.color.accentSoft
              : root.hovered ? root.tokens.color.surface : root.tokens.frosted ? root.tokens.material.panel : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Item {
        NayoriMark {
            variant: root.iconStyle
            anchors.centerIn: parent
            ink: root.enabled ? root.tokens.color.text : root.tokens.color.textMuted
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
