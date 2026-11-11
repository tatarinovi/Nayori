import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.

import QtQuick

StyledText {
    readonly property var nayoriMaterialSymbol: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real iconSize: nayoriMaterialSymbol.appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    // Keep the font on a complete outlined or filled glyph. Fractional FILL
    // values during animation can drop internal paths in Qt's variable-font
    // renderer after a parent scale transform.
    readonly property real truncatedFill: root.fill >= 0.5 ? 1 : 0

    // QtRendering can omit contours from filled variable-font glyphs (notably
    // `devices`) at small sizes. NativeRendering uses the font engine's glyph
    // rasterizer and preserves the complete FILL outline.
    renderType: Text.NativeRendering
    antialiasing: true
    smooth: true
    horizontalAlignment: Text.AlignHCenter

    font {
        hintingPreference: Font.PreferNoHinting
        family: nayoriMaterialSymbol.appearance?.font.family.iconMaterial ?? "Material Symbols Rounded"
        pixelSize: iconSize
        weight: Font.Normal
        variableAxes: ({
                "FILL": parseFloat(root.truncatedFill),
                "wght": 400,
                "opsz": Math.max(20, Math.min(48, iconSize))
            })
    }

    Behavior on fill {
        NumberAnimation {
            duration: nayoriMaterialSymbol.appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: nayoriMaterialSymbol.appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: nayoriMaterialSymbol.appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}

