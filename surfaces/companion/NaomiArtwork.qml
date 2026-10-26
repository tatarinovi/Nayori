pragma ComponentBehavior: Bound
import QtQuick

// Keep one appearance loaded; the companion/controller/bubble survive a style change.
Item {
    id: root
    required property var tokens
    property string style: "current"
    property bool active: true
    property bool animationsEnabled: true
    property bool followPointer: false
    property bool pointerTracking: false
    property real pet: 0
    property real petLean: 0
    readonly property bool pointerInside: picture.item ? picture.item.pointerInside : false
    readonly property rect headRect: picture.item ? picture.item.headRect : Qt.rect(0,0,0,0)
    readonly property point bubbleAnchor: picture.item ? picture.item.bubbleAnchor : Qt.point(0,0)
    readonly property var renderer: picture.item
    signal pointerMoved(real x, real y)
    Loader {
        id: picture
        anchors.fill: parent
        sourceComponent: root.style === "pixel-art" ? pixel : current
    }
    Component {
        id: current
        NaomiIllustration {
            tokens: root.tokens
            active: root.active
            animationsEnabled: root.animationsEnabled
            followPointer: root.followPointer
            pointerTracking: root.pointerTracking
            pet: root.pet
            petLean: root.petLean
            onPointerMoved: (x,y) => root.pointerMoved(x,y)
        }
    }
    Component {
        id: pixel
        NaomiPixelIllustration {
            tokens: root.tokens
            active: root.active
            animationsEnabled: root.animationsEnabled
            followPointer: root.followPointer
            pointerTracking: root.pointerTracking
            pet: root.pet
            petLean: root.petLean
            onPointerMoved: (x,y) => root.pointerMoved(x,y)
        }
    }
}
