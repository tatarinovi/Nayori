import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import Quickshell



Item {
    readonly property var nayoriRegaliaPlate: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property color fillColor: nayoriRegaliaPlate.appearance.regalia.surfacePlate
    property real radius: nayoriRegaliaPlate.appearance.regalia.roundNormal
    property real inset: nayoriRegaliaPlate.appearance.regalia.surfaceInset
    property bool elevated: false
    property bool deepFrame: false
    property bool active: false
    property bool hovered: false
    property bool glassEnabled: false
    property real glassScreenX: {
        void root.width
        void root.height
        return root.mapToItem(null, 0, 0).x
    }
    property real glassScreenY: {
        void root.width
        void root.height
        return root.mapToItem(null, 0, 0).y
    }
    property real glassScreenWidth: root.QsWindow?.window?.screen?.width ?? (Quickshell.screens[0]?.width ?? 1920)
    property real glassScreenHeight: root.QsWindow?.window?.screen?.height ?? (Quickshell.screens[0]?.height ?? 1080)

    readonly property bool _glassActive: root.glassEnabled && nayoriRegaliaPlate.appearance.regalia.glass && nayoriRegaliaPlate.appearance.effectsEnabled
    readonly property real _materialStrength: Math.max(0, Math.min(1, nayoriRegaliaPlate.appearance.regalia.glassSurfaceOpacity))
    readonly property real _glassFrameOpacity: 0.58 + root._materialStrength * 0.34
    readonly property real _glassFieldOpacity: 0.22 + root._materialStrength * 0.50
    readonly property color _frameColor: root.elevated
        ? nayoriRegaliaPlate.appearance.regalia.chassis2
        : root.deepFrame ? nayoriRegaliaPlate.appearance.regalia.chassis0 : nayoriRegaliaPlate.appearance.regalia.chassis1
    readonly property color _fieldColor: root.active
        ? nayoriRegaliaPlate.appearance.regalia.surfacePlateActive
        : root.hovered ? nayoriRegaliaPlate.appearance.regalia.surfacePlateHover : root.fillColor
    readonly property color _paintFrameColor: root._glassActive
        ? nayoriRegaliaPlate.colorUtils.applyAlpha(root._frameColor, root._glassFrameOpacity) : root._frameColor
    readonly property color _paintFieldColor: root._glassActive
        ? nayoriRegaliaPlate.colorUtils.applyAlpha(root._fieldColor, root._glassFieldOpacity) : root._fieldColor

    GlassBackground {
        anchors.fill: parent
        visible: root._glassActive
        forceBackdrop: true
        blurStrength: nayoriRegaliaPlate.appearance.regalia.glassBlur
        saturationStrength: nayoriRegaliaPlate.appearance.regalia.glassSaturation
        auroraTransparency: nayoriRegaliaPlate.appearance.regalia.glassTintTransparency
        radius: root.radius
        screenX: root.glassScreenX
        screenY: root.glassScreenY
        screenWidth: root.glassScreenWidth
        screenHeight: root.glassScreenHeight
    }

    Rectangle {
        id: chassis
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._glassActive
                    ? nayoriRegaliaPlate.colorUtils.applyAlpha(root.elevated ? nayoriRegaliaPlate.appearance.regalia.chassisLight : root._frameColor, root._glassFrameOpacity)
                    : (root.elevated ? nayoriRegaliaPlate.appearance.regalia.chassisLight : root._frameColor)
            }
            GradientStop { position: 0.42; color: root._paintFrameColor }
            GradientStop {
                position: 1
                color: root._glassActive
                    ? nayoriRegaliaPlate.colorUtils.applyAlpha(nayoriRegaliaPlate.appearance.regalia.chassisShade, root._glassFrameOpacity)
                    : nayoriRegaliaPlate.appearance.regalia.chassisShade
            }
        }
    }

    Rectangle {
        id: field
        anchors.fill: parent
        anchors.margins: root.inset
        radius: Math.max(0, root.radius - root.inset)
        color: root._paintFieldColor
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._glassActive
                    ? nayoriRegaliaPlate.colorUtils.applyAlpha(nayoriRegaliaPlate.colorUtils.mix(root._fieldColor, nayoriRegaliaPlate.appearance.regalia.onColor, 0.965), root._glassFieldOpacity)
                    : nayoriRegaliaPlate.colorUtils.mix(root._fieldColor, nayoriRegaliaPlate.appearance.regalia.onColor, 0.965)
            }
            GradientStop { position: 0.52; color: root._paintFieldColor }
            GradientStop {
                position: 1
                color: root._glassActive
                    ? nayoriRegaliaPlate.colorUtils.applyAlpha(nayoriRegaliaPlate.colorUtils.mix(root._fieldColor, nayoriRegaliaPlate.appearance.m3colors.m3shadow, 0.94), root._glassFieldOpacity)
                    : nayoriRegaliaPlate.colorUtils.mix(root._fieldColor, nayoriRegaliaPlate.appearance.m3colors.m3shadow, 0.94)
            }
        }

        Behavior on color {
            enabled: nayoriRegaliaPlate.appearance.animationsEnabled
            ColorAnimation { duration: nayoriRegaliaPlate.appearance.regalia.stateDuration; easing.type: Easing.OutCubic }
        }
    }
}
