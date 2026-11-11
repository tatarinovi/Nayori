import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes as Shapes
import QtQuick.Layouts






AbstractBackgroundWidget {
    readonly property var nayoriCirclePointerClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "circle_pointer_clock"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriCirclePointerClockWidget.config.options.lock.centerWidget === "circle_pointer_clock")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriCirclePointerClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriCirclePointerClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property real contentScale: (nayoriCirclePointerClockWidget.config.options.background.widgets.circle_pointer_clock.widgetSize ?? 100) / 100.0
    implicitWidth:  240 * contentScale
    implicitHeight: 240 * contentScale

    // ── Config options bound directly to Config ────────────────────────────────
    readonly property bool cfgUseBlackBg:
        nayoriCirclePointerClockWidget.config.ready ? (nayoriCirclePointerClockWidget.config.options.background.widgets.circle_pointer_clock.useBlackBg ?? true) : true
    readonly property bool cfgEnableGlassReflection:
        nayoriCirclePointerClockWidget.config.ready ? (nayoriCirclePointerClockWidget.config.options.background.widgets.circle_pointer_clock.enableGlassReflection ?? false) : false
    readonly property bool cfgShowDots:
        nayoriCirclePointerClockWidget.config.ready ? (nayoriCirclePointerClockWidget.config.options.background.widgets.circle_pointer_clock.showDots ?? true) : true
    readonly property bool cfgBoldFont:
        nayoriCirclePointerClockWidget.config.ready ? (nayoriCirclePointerClockWidget.config.options.background.widgets.circle_pointer_clock.boldFont ?? true) : true

    readonly property color colBg: cfgUseBlackBg ? nayoriCirclePointerClockWidget.colors.m3colors.m3shadow
                                                : nayoriCirclePointerClockWidget.colors.cardBgColor

    // ── Shadow + Container ────────────────────────────────────────────────────
    StyledDropShadow {
        target: clockBgShape
        visible: nayoriCirclePointerClockWidget.config.options.background.widgets.enableShadows ?? true
    }

    Item {
        id: clockContainer
        anchors.centerIn: parent
        width:  root.implicitWidth
        height: root.implicitHeight

        // 1. MaterialShape Circle Background
        MaterialShape {
            id: clockBgShape
            anchors.fill: parent
            shape: MaterialShape.Shape.Circle
            color: nayoriCirclePointerClockWidget.colors.tintBackground(root.colBg)
        }

        // 2. Dial & Pointer Canvas Overlay
        // Supersampled: this dial is a Canvas, so it rasterises at its own
        // item size. Without this it would be a stretched bitmap the moment
        // the widget is scaled up.
        Supersampled {
            anchors.fill: parent
            factor: root.renderScale

            CirclePointerClock {
                anchors.fill: parent
                useBlackBg:            root.cfgUseBlackBg
                enableGlassReflection: root.cfgEnableGlassReflection
                showDots:              root.cfgShowDots
                boldFont:              root.cfgBoldFont
            }
        }

        // ── 3D Glass Dome Reflection ──────────────────────────────────────────
        Item {
            id: glassReflectionOverlay
            anchors.fill: parent
            z: 10
            enabled: false
            visible: root.cfgEnableGlassReflection

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Item {
                    width: glassReflectionOverlay.width
                    height: glassReflectionOverlay.height
                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Circle
                        color: "white"
                    }
                }
            }

            // Top-Right crescent reflection
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: FastBlur { radius: 28 }

                Shapes.Shape {
                    id: topMaskShape
                    anchors.fill: parent
                    visible: false
                    Shapes.ShapePath {
                        strokeColor: "transparent"
                        fillColor:   "white"
                        startX: parent.width  * 0.40
                        startY: parent.height * 0.04
                        PathArc {
                            x: topMaskShape.width  * 0.96
                            y: topMaskShape.height * 0.60
                            radiusX: topMaskShape.width  * 0.48
                            radiusY: topMaskShape.height * 0.48
                            useLargeArc: false
                        }
                        PathArc {
                            x: topMaskShape.width  * 0.40
                            y: topMaskShape.height * 0.04
                            radiusX: topMaskShape.width  * 0.35
                            radiusY: topMaskShape.height * 0.35
                            useLargeArc: false
                            direction: PathArc.Counterclockwise
                        }
                    }
                }

                LinearGradient {
                    anchors.fill: parent
                    start: Qt.point(width * 0.40, height * 0.04)
                    end:   Qt.point(width * 0.96, height * 0.60)
                    cached: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.3; color: nayoriCirclePointerClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 0.7; color: nayoriCirclePointerClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: topMaskShape }
                }
            }

            // Bottom-Left crescent reflection
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: FastBlur { radius: 28 }

                Shapes.Shape {
                    id: bottomMaskShape
                    anchors.fill: parent
                    visible: false
                    Shapes.ShapePath {
                        strokeColor: "transparent"
                        fillColor:   "white"
                        startX: parent.width  * 0.60
                        startY: parent.height * 0.96
                        PathArc {
                            x: bottomMaskShape.width  * 0.04
                            y: bottomMaskShape.height * 0.40
                            radiusX: bottomMaskShape.width  * 0.48
                            radiusY: bottomMaskShape.height * 0.48
                            useLargeArc: false
                        }
                        PathArc {
                            x: bottomMaskShape.width  * 0.60
                            y: bottomMaskShape.height * 0.96
                            radiusX: bottomMaskShape.width  * 0.35
                            radiusY: bottomMaskShape.height * 0.35
                            useLargeArc: false
                            direction: PathArc.Counterclockwise
                        }
                    }
                }

                LinearGradient {
                    anchors.fill: parent
                    start: Qt.point(width * 0.60, height * 0.96)
                    end:   Qt.point(width * 0.04, height * 0.40)
                    cached: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.3; color: nayoriCirclePointerClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 0.7; color: nayoriCirclePointerClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: bottomMaskShape }
                }
            }
        }
    }
}
