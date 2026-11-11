import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Qt5Compat.GraphicalEffects


DropShadow {
    readonly property var nayoriStyledDropShadow: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    required property var target
    source: target
    x: source?.x ?? 0
    y: source?.y ?? 0
    width: source?.width ?? 0
    height: source?.height ?? 0
    radius: 8
    samples: radius * 2 + 1
    color: nayoriStyledDropShadow.appearance.colors.colShadow
    transparentBorder: true
    visible: opacity > 0 && !nayoriStyledDropShadow.config.options.appearance.transparency.popups && !nayoriStyledDropShadow.config.options.appearance.transparency.enable
}
