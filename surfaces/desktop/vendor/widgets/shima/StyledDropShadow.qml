import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import Qt5Compat.GraphicalEffects


DropShadow {
    readonly property var nayoriStyledDropShadow: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    required property var target
    visible: nayoriStyledDropShadow.appearance.effectsEnabled && !nayoriStyledDropShadow.appearance.zzzEverywhere
    source: target
    anchors.fill: source
    radius: nayoriStyledDropShadow.appearance.effectsEnabled ? 8 : 0
    samples: radius * 2 + 1
    color: nayoriStyledDropShadow.appearance.colors.colShadow
    transparentBorder: true
}
