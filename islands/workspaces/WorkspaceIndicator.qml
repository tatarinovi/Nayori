pragma ComponentBehavior: Bound

import QtQuick
import "WorkspaceStyles.js" as Styles

// Shared by the live track and settings previews; owns no compositor state.
Item {
    id: root
    required property var tokens
    property string style: "dots"
    property int number: 1
    property bool current: false
    property bool occupied: false
    property bool urgent: false
    property bool externalMarker: false
    readonly property bool geometric: style === "dots" || style === "dashes"
    readonly property color ink: urgent ? tokens.color.secondary
        : current || occupied ? tokens.color.accent : tokens.color.textMuted
    implicitWidth: 28
    implicitHeight: 32

    Rectangle {
        anchors.centerIn: parent
        visible: root.current && !root.externalMarker
        width: root.geometric ? 24 : 26
        height: root.geometric ? 8 : 26
        radius: root.geometric ? 4 : 8
        color: root.geometric ? root.tokens.color.accent : root.tokens.color.accentSoft
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.geometric
        width: root.style === "dashes" ? 16 : 7
        height: root.style === "dashes" ? 4 : 7
        radius: height / 2
        color: root.occupied || root.urgent ? root.ink : "transparent"
        border.width: root.occupied || root.urgent ? 0 : 1
        border.color: root.ink
        opacity: root.current ? 0 : 1
        scale: root.current ? 1.3 : root.occupied ? 1 : 0.8
        Behavior on scale { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
    }
    Text {
        anchors.centerIn: parent
        visible: !root.geometric && root.style !== "icons"
        text: Styles.label(root.style, root.number)
        color: root.ink
        font.family: root.tokens.type.body.family
        font.pixelSize: root.style === "kanji" ? 15 : 13
        font.weight: root.current || root.occupied ? Font.DemiBold : Font.Normal
        scale: root.current ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.OutCubic } }
    }
    // A tiny workspace/window pictogram, independent of icon fonts and themes.
    Rectangle {
        anchors.centerIn: parent
        visible: root.style === "icons"
        width: 14; height: 12; radius: 3
        color: root.current ? root.tokens.color.accent : "transparent"
        border.width: 1; border.color: root.ink
        scale: root.current ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.OutCubic } }
        Rectangle {
            x: 3; y: 4; width: 8; height: 1
            color: root.current ? root.tokens.material.panel : root.ink
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        visible: root.urgent || (!root.geometric && root.occupied)
        width: 3; height: 3; radius: 1.5
        color: root.ink
    }
}
