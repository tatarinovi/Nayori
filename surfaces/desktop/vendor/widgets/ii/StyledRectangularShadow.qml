import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects


RectangularShadow {
    readonly property var nayoriStyledRectangularShadow: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: shadow
    required property var target
    anchors.fill: (target && shadow.parent && (target.parent === shadow.parent || target === shadow.parent)) ? target : parent
    radius: (target && typeof target.radius === "number") ? target.radius : 0
    blur: 0.9 * nayoriStyledRectangularShadow.appearance.sizes.elevationMargin
    offset: Qt.vector2d(0.0, 1.0)
    spread: 1
    color: nayoriStyledRectangularShadow.appearance.colors.colShadow
    cached: true
    opacity: target ? target.opacity : 1.0
    visible: opacity > 0 && !nayoriStyledRectangularShadow.config.options.appearance.transparency.popups && !nayoriStyledRectangularShadow.config.options.appearance.transparency.enable
}
