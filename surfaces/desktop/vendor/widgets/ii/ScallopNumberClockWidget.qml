import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes as Shapes
import QtQuick.Layouts






AbstractBackgroundWidget {
    readonly property var nayoriScallopNumberClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "scallop_number_clock"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriScallopNumberClockWidget.config.options.lock.centerWidget === "scallop_number_clock")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriScallopNumberClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriScallopNumberClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property real contentScale: (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.widgetSize ?? 100) / 100.0
    implicitWidth:  240 * contentScale
    implicitHeight: 240 * contentScale

    // ── Config options bound directly to Config ────────────────────────────────
    readonly property bool cfgUseBlackBg:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.useBlackBg ?? true) : true
    readonly property bool cfgEnableGlassReflection:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.enableGlassReflection ?? false) : false
    readonly property bool cfgShowHourHand:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.showHourHand ?? true) : true
    readonly property bool cfgShowMinuteBubble:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.showMinuteBubble ?? true) : true
    readonly property bool cfgShowDots:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.showDots ?? true) : true
    readonly property bool cfgBoldFont:
        nayoriScallopNumberClockWidget.config.ready ? (nayoriScallopNumberClockWidget.config.options.background.widgets.scallop_number_clock.boldFont ?? true) : true

    readonly property color colBg: cfgUseBlackBg ? nayoriScallopNumberClockWidget.colors.m3colors.m3shadow
                                                : nayoriScallopNumberClockWidget.colors.cardBgColor

    // ── Shadow + Container ────────────────────────────────────────────────────
    StyledDropShadow {
        target: clockBgShape
        visible: nayoriScallopNumberClockWidget.config.options.background.widgets.enableShadows ?? true
    }

    Item {
        id: clockContainer
        anchors.centerIn: parent
        width:  root.implicitWidth
        height: root.implicitHeight

        // 1. MaterialShape Cookie12Sided Outer Background
        MaterialShape {
            id: clockBgShape
            anchors.fill: parent
            shape: MaterialShape.Shape.Cookie12Sided
            color: nayoriScallopNumberClockWidget.colors.tintBackground(root.colBg)
        }

        // 2. Numbers & Bubbles Canvas Overlay
        // Supersampled: this dial is a Canvas, so it rasterises at its own
        // item size. Without this it would be a stretched bitmap the moment
        // the widget is scaled up.
        Supersampled {
            anchors.fill: parent
            factor: root.renderScale

            ScallopNumberClock {
                anchors.fill: parent
                useBlackBg:            root.cfgUseBlackBg
                enableGlassReflection: root.cfgEnableGlassReflection
                showHourHand:          root.cfgShowHourHand
                showMinuteBubble:      root.cfgShowMinuteBubble
                showDots:              root.cfgShowDots
                boldFont:              root.cfgBoldFont
            }
        }

        // 3. Center Cookie12Sided Date Badge (Day of Month & Weekday)
        Item {
            id: centerBadge
            anchors.centerIn: parent
            width:  parent.width  * 0.29
            height: parent.height * 0.29
            z: 5

            MaterialShape {
                anchors.fill: parent
                shape: MaterialShape.Shape.Cookie12Sided
                color: nayoriScallopNumberClockWidget.colors.pillFillColor
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2 * root.contentScale

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().toString(nayoriScallopNumberClockWidget.dateTime.clock.date, "dd")
                    font.pixelSize: Math.round(centerBadge.width * 0.32)
                    font.weight: Font.Bold
                    font.family: nayoriScallopNumberClockWidget.appearance.font.family.main
                    color: nayoriScallopNumberClockWidget.colors.textColorOnPillFill
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().toString(nayoriScallopNumberClockWidget.dateTime.clock.date, "ddd").toUpperCase()
                    font.pixelSize: Math.round(centerBadge.width * 0.20)
                    font.weight: Font.Bold
                    font.family: nayoriScallopNumberClockWidget.appearance.font.family.main
                    color: nayoriScallopNumberClockWidget.colors.textColorOnPillFill
                }
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
                        shape: MaterialShape.Shape.Cookie12Sided
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
                        GradientStop { position: 0.3; color: nayoriScallopNumberClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 0.7; color: nayoriScallopNumberClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
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
                        GradientStop { position: 0.3; color: nayoriScallopNumberClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 0.7; color: nayoriScallopNumberClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: bottomMaskShape }
                }
            }
        }
    }
}
