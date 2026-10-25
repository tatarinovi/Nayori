pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Clips arbitrary content to a rounded rectangle.
Item {
    id: rounded
    property real radius: 10
    default property alias content: holder.data
    Item {
        id: holder
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: rounded.radius; color: "white"; layer.enabled: true; visible: false }
}
