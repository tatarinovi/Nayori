pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property color accent
    property real pulse: 0
    property real attachment: 0
    property real cornerRadius: 24
    visible: pulse > 0.001
    AttachedPath {
        objectName: "attachedBeatStroke"
        anchors.fill: parent
        visible: root.attachment > 0
        attachment: root.attachment
        cornerRadius: root.cornerRadius
        strokeColor: root.accent
        strokeWidth: 5
        opacity: Math.max(0, Math.min(1, root.pulse)) * 0.45
    }
    Rectangle {
        objectName: "musicBeatStroke"
        visible: root.attachment === 0
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.color: root.accent
        border.width: 5
        opacity: Math.max(0, Math.min(1, root.pulse)) * 0.45
        antialiasing: true
    }
}
