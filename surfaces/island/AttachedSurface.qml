pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    property real attachment: 0
    property alias radius: floating.radius
    property alias color: floating.color
    property alias border: floating.border
    readonly property real shoulder: Math.min(12, width / 4, height / 4) * attachment
    Rectangle {
        id: floating
        anchors.fill: parent
        z: -1
        visible: root.attachment === 0
        antialiasing: true
    }
    AttachedPath {
        objectName: "attachedContour"
        anchors.fill: parent
        z: -1
        visible: root.attachment > 0
        attachment: root.attachment
        cornerRadius: root.radius
        fillColor: root.color
        strokeColor: root.border.color
        strokeWidth: root.border.width
    }
}
