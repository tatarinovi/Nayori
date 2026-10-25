pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: root
    required property var tokens
    property url source
    property real radius: tokens.radius.medium
    readonly property bool ready: artwork.status === Image.Ready

    // Blur an oversized image first. Clip the complete dimmed composition once,
    // so blur sampling never reads transparent pixels along the card contour.
    Item {
        id: composition
        anchors.fill: parent
        visible: root.ready
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: roundedMask
        }
        clip: true
        Image {
            id: artwork
            anchors.fill: parent
            anchors.margins: -48
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: artwork
            source: artwork
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: 1
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(root.tokens.color.background, 0.68) }
    }
    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        layer.enabled: true
        visible: false
    }
}
