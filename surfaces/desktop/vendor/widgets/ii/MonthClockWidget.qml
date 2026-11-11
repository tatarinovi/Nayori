import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes as Shapes
import QtQuick.Layouts






AbstractBackgroundWidget {
    readonly property var nayoriMonthClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "month_clock"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriMonthClockWidget.config.options.lock.centerWidget === "month_clock")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriMonthClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriMonthClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property real contentScale: (nayoriMonthClockWidget.config.options.background.widgets.month_clock.widgetSize ?? 100) / 100.0
    implicitWidth:  240 * contentScale
    implicitHeight: 240 * contentScale

    // ── Config options bound directly to Config ────────────────────────────────
    readonly property bool cfgUseBlackBg:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.useBlackBg ?? true) : true
    readonly property bool cfgEnableGlassReflection:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.enableGlassReflection ?? false) : false
    readonly property bool cfgShowMonthRing:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showMonthRing ?? true) : true
    readonly property bool cfgShowDayRing:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showDayRing ?? true) : true
    readonly property bool cfgShowWeekRing:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showWeekRing ?? true) : true
    readonly property bool cfgShowMonthPill:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showMonthPill ?? true) : true
    readonly property bool cfgShowDayPill:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showDayPill ?? true) : true
    readonly property bool cfgShowWeekPill:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showWeekPill ?? true) : true
    readonly property bool cfgShowTickMarks:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.showTickMarks ?? true) : true
    readonly property bool cfgBoldFont:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.boldFont ?? true) : true

    readonly property string cfgHourHandStyle:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.hourHandStyle ?? "hollow") : "hollow"
    readonly property string cfgMinuteHandStyle:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.minuteHandStyle ?? "bold") : "bold"
    readonly property string cfgSecondHandStyle:
        nayoriMonthClockWidget.config.ready ? (nayoriMonthClockWidget.config.options.background.widgets.month_clock.secondHandStyle ?? "line") : "line"

    property int clockSecond: nayoriMonthClockWidget.dateTime.clock.seconds
    Timer {
        running: root.cfgSecondHandStyle !== "hide" && root.live
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.clockSecond = new Date().getSeconds()
    }

    // ── Dynamic Color System (Matching CookieClock color assignments) ───────────
    readonly property color colHourHand:   nayoriMonthClockWidget.colors.accentColor
    readonly property color colMinuteHand: nayoriMonthClockWidget.colors.subtextColorOnBg
    readonly property color colSecondHand: nayoriMonthClockWidget.colors.warningColor
    readonly property color colCenterDot:  nayoriMonthClockWidget.colors.pillFillColor

    // ── Shadow + Container ────────────────────────────────────────────────────
    StyledDropShadow {
        target: clockBgCircle
        visible: nayoriMonthClockWidget.config.options.background.widgets.enableShadows ?? true
    }

    Item {
        id: clockContainer
        anchors.centerIn: parent
        width:  root.implicitWidth
        height: root.implicitHeight

        // Black/card background circle + clip
        Rectangle {
            id: clockBgCircle
            anchors.fill: parent
            radius: width / 2
            color: nayoriMonthClockWidget.colors.tintBackground(root.cfgUseBlackBg
                ? nayoriMonthClockWidget.colors.m3colors.m3shadow : nayoriMonthClockWidget.colors.cardBgColor)
            clip: true

            // 1. Main Calendar Dial Canvas
            // Supersampled: this dial is a Canvas, so it rasterises at its own
            // item size. Without this it would be a stretched bitmap the moment
            // the widget is scaled up.
            Supersampled {
                anchors.fill: parent
                factor: root.renderScale

                MonthClock {
                    anchors.fill: parent
                    useBlackBg:            root.cfgUseBlackBg
                    enableGlassReflection: root.cfgEnableGlassReflection
                    showMonthRing:         root.cfgShowMonthRing
                    showDayRing:           root.cfgShowDayRing
                    showWeekRing:          root.cfgShowWeekRing
                    showMonthPill:         root.cfgShowMonthPill
                    showDayPill:           root.cfgShowDayPill
                    showWeekPill:          root.cfgShowWeekPill
                    showTickMarks:         root.cfgShowTickMarks
                    boldFont:              root.cfgBoldFont
                }
            }

            // 2. Minute Hand (Distinct color: subtextColorOnBg)
            FadeLoader {
                anchors.fill: parent
                z: 1
                shown: root.cfgMinuteHandStyle !== "hide"
                sourceComponent: MinuteHand {
                    anchors.fill: parent
                    clockMinute: nayoriMonthClockWidget.dateTime.clock.minutes
                    style: root.cfgMinuteHandStyle
                    color: root.colMinuteHand
                }
            }

            // 3. Hour Hand (Distinct color: accentColor)
            FadeLoader {
                anchors.fill: parent
                z: (item && item.style === "hollow") ? 0 : 2
                shown: root.cfgHourHandStyle !== "hide"
                sourceComponent: HourHand {
                    clockHour: nayoriMonthClockWidget.dateTime.clock.hours % 12
                    clockMinute: nayoriMonthClockWidget.dateTime.clock.minutes
                    style: root.cfgHourHandStyle
                    color: root.colHourHand
                }
            }

            // 4. Second Hand (Vibrant Warning Color)
            FadeLoader {
                anchors.fill: parent
                z: (root.cfgSecondHandStyle === "line") ? 2 : 3
                shown: root.cfgSecondHandStyle !== "hide"
                sourceComponent: SecondHand {
                    clockSecond: root.clockSecond
                    style: root.cfgSecondHandStyle
                    color: root.colSecondHand
                }
            }

            // 5. Center Pivot Dot (Pill fill color)
            FadeLoader {
                z: 4
                anchors.centerIn: parent
                shown: root.cfgMinuteHandStyle !== "hide" || root.cfgHourHandStyle !== "hide" || root.cfgSecondHandStyle !== "hide"
                sourceComponent: Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.colCenterDot
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
                    Rectangle {
                        id: outerMaskBase
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }
                    FastBlur {
                        anchors.fill: parent
                        source: outerMaskBase
                        radius: 3
                    }
                }
            }

            // Top-Right crescent
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
                        GradientStop { position: 0.3; color: nayoriMonthClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 0.7; color: nayoriMonthClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: topMaskShape }
                }
            }

            // Bottom-Left crescent
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
                        GradientStop { position: 0.3; color: nayoriMonthClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 0.7; color: nayoriMonthClockWidget.colorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: bottomMaskShape }
                }
            }
        }
    }
}
