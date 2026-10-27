pragma ComponentBehavior: Bound
import QtQuick
import "../../services/companion/NaomiBehavior.js" as Pet

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
    property bool speaking: false
    readonly property bool pointerInside: picture.item ? picture.item.pointerInside : false
    readonly property rect headRect: picture.item ? picture.item.headRect : Qt.rect(0,0,0,0)
    readonly property point bubbleAnchor: picture.item ? picture.item.bubbleAnchor : Qt.point(0,0)
    readonly property var renderer: picture.item
    signal pointerMoved(real x, real y)
    Loader {
        id: picture
        anchors.fill: parent
        sourceComponent: root.style === "layered" ? layered
            : root.style === "haori" ? haori
            : root.style === "pixel-art" ? pixel
            : current
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
    Component {
        id: haori
        NaomiHaori {
            id: haoriSprite
            active: root.active
            animationsEnabled: root.animationsEnabled && !root.tokens.motion.off
            pet: root.pet
            petLean: root.petLean
            speaking: root.speaking
            accentColor: root.tokens.color.accent
            readonly property bool pointerInside: haoriPointer.hovered
            HoverHandler {
                id: haoriPointer
                enabled: root.followPointer || root.pointerTracking
                onPointChanged: {
                    if (!hovered || haoriSprite.headRect.width <= 0) return
                    const zone = Pet.zone(), h = haoriSprite.headRect
                    root.pointerMoved(zone.x + (point.position.x-h.x)/h.width*zone.w,
                                      zone.y + (point.position.y-h.y)/h.height*zone.h)
                }
            }
        }
    }
    Component {
        id: layered
        NaomiSprite {
            id: sprite
            active: root.active
            animationsEnabled: root.animationsEnabled && !root.tokens.motion.off
            readonly property bool pointerInside: pointer.hovered
            HoverHandler {
                id: pointer
                enabled: root.followPointer || root.pointerTracking
                onPointChanged: {
                    if (!hovered || sprite.headRect.width <= 0) return
                    const zone = Pet.zone(), h = sprite.headRect
                    root.pointerMoved(zone.x + (point.position.x-h.x)/h.width*zone.w,
                                      zone.y + (point.position.y-h.y)/h.height*zone.h)
                }
            }
        }
    }
}
