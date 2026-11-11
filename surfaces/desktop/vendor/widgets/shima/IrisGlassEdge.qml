import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Effects



// Native borders keep the curve antialiased; the light is faded downward by a smooth vertical mask, never a
// ring mask (that pixelated every corner).
Item {
    readonly property var nayoriIrisGlassEdge: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real radius: 0
    readonly property real lineWidth: Math.max(1, Math.round(nayoriIrisGlassEdge.irisStyle.glassEdgeWidth * nayoriIrisGlassEdge.irisStyle.density))
    readonly property bool shown: nayoriIrisGlassEdge.irisStyle.glassEdgeLight > 0 || nayoriIrisGlassEdge.irisStyle.glassEdgeLine > 0
    visible: root.shown

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: nayoriIrisGlassEdge.irisStyle.glassEdgeLine > 0 ? root.lineWidth : 0
        border.color: nayoriIrisGlassEdge.colorUtils.applyAlpha(nayoriIrisGlassEdge.irisStyle.glassEdgeColour, nayoriIrisGlassEdge.irisStyle.glassEdgeLine)
    }

    Rectangle {
        anchors.fill: parent
        visible: nayoriIrisGlassEdge.irisStyle.glassEdgeLight > nayoriIrisGlassEdge.irisStyle.glassEdgeLine
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.lineWidth
        border.color: nayoriIrisGlassEdge.colorUtils.applyAlpha(nayoriIrisGlassEdge.irisStyle.glassEdgeColour, nayoriIrisGlassEdge.irisStyle.glassEdgeLight)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: litFade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Rectangle {
        id: litFade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }
}
