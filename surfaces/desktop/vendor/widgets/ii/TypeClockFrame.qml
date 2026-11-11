import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects




/*
 * The card behind the Weight, Width and Stack type clocks, which can be turned
 * off. Without it the type sits straight on the wallpaper, optionally with a
 * soft shadow under it to keep it legible on busy pictures. Children go in
 * `content`, a box of the design size.
 */
Item {
    readonly property var nayoriTypeClockFrame: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property bool showBackground: true
    property bool textShadow: true
    default property alias content: contentLayer.data

    StyledRectangularShadow {
        target: card
        visible: root.showBackground && (nayoriTypeClockFrame.config.options.background.widgets.enableShadows ?? true)
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: nayoriTypeClockFrame.appearance.rounding.large
        color: root.showBackground ? nayoriTypeClockFrame.colors.tintBackground(nayoriTypeClockFrame.colors.cardBgColor) : "transparent"

        Behavior on color {
            animation: nayoriTypeClockFrame.appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    Item {
        id: contentLayer
        anchors.fill: parent
        layer.enabled: !root.showBackground && root.textShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: nayoriTypeClockFrame.colors.colors.colShadow
            shadowBlur: 1.0
            shadowOpacity: 0.8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }
}
