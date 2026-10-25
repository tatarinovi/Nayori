pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property color accent
    property real pulse: 0
    property real cornerRadius: 24
    visible: pulse > 0.001
    Rectangle {
        objectName: "musicBeatStroke"
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.color: root.accent
        border.width: 2
        opacity: Math.max(0, Math.min(1, root.pulse)) * 0.45
        antialiasing: true
    }
}
