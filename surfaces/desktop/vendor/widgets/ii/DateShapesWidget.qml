import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import Quickshell.Widgets





/*
 * Date Shapes (2x1). Less to read, more to look at: the weekday as a heavy
 * rounded headline, the month on an accent chip, the day of the month on a
 * big shape bleeding off the card's corner (it changes shape under the
 * pointer), and the week as seven little shapes - gone days filled, today a
 * sunny burst, days ahead hollow.
 */
AbstractBackgroundWidget {
    readonly property var nayoriDateShapesWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "calendar_date_shapes"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriDateShapesWidget.config.options.lock.centerWidget === "calendar_date_shapes")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriDateShapesWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriDateShapesWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriDateShapesWidget.config.options?.background?.widgets?.calendar_date_shapes ?? ({})
    readonly property real contentScale: (root.options?.widgetSize ?? 100) / 100.0
    readonly property var dayShape: MaterialShape.Shape[root.options?.dayShape ?? "Clover4Leaf"] ?? MaterialShape.Shape.Clover4Leaf
    // Under the pointer the day's shape turns into this one (or a cookie, if it already is).
    readonly property var hoverShape: root.dayShape === MaterialShape.Shape.Cookie12Sided
        ? MaterialShape.Shape.Cookie9Sided : MaterialShape.Shape.Cookie12Sided
    readonly property bool showWeekShapes: root.options?.showWeekShapes ?? true

    // -- Geometry (design units) --
    readonly property real designWidth: 492
    readonly property real designHeight: 240
    readonly property real padding: 22
    readonly property real shapeSize: 270
    // How much of the shape, per axis, stays on the card.
    readonly property real shapeOnCard: 0.74
    readonly property real dayFigureSize: 124
    readonly property real textColumnWidth: 250
    readonly property real weekDot: 14
    readonly property real todayDot: 26
    readonly property real weekGap: 9

    implicitWidth: root.designWidth * root.contentScale
    implicitHeight: root.designHeight * root.contentScale

    CalendarWidgetData {
        id: cal
    }

    Item {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: root.contentScale

        HoverHandler {
            id: hover
        }

        StyledRectangularShadow {
            target: card
            visible: nayoriDateShapesWidget.config.options.background.widgets.enableShadows ?? true
        }

        ClippingRectangle {
            id: card
            anchors.fill: parent
            radius: nayoriDateShapesWidget.appearance.rounding.large
            color: nayoriDateShapesWidget.colors.tintBackground(nayoriDateShapesWidget.colors.cardBgColor)

            // -- The day on its shape, bleeding off the bottom-right corner --
            MaterialShape {
                id: bigShape
                x: card.width - root.shapeSize * root.shapeOnCard
                y: card.height - root.shapeSize * root.shapeOnCard
                implicitSize: root.shapeSize
                shape: hover.hovered ? root.hoverShape : root.dayShape
                color: nayoriDateShapesWidget.colors.accentColor
            }

            Text {
                // Centred on the part of the shape that is on the card.
                x: bigShape.x + (card.width - bigShape.x - width) / 2
                y: bigShape.y + (card.height - bigShape.y - height) / 2
                text: cal.today.getDate()
                color: nayoriDateShapesWidget.colors.onAccentColor
                font.family: nayoriDateShapesWidget.appearance.font.family.main
                font.pixelSize: Math.round(root.dayFigureSize)
                font.variableAxes: ({ "wght": 860, "wdth": 30, "ROND": 100, "opsz": 144 })
                renderType: Text.QtRendering
            }

            // -- Weekday and month --
            Text {
                id: weekday
                x: root.padding
                y: root.padding - 6
                width: root.textColumnWidth
                height: 84
                text: cal.locale.toString(cal.today, "dddd").toUpperCase()
                color: nayoriDateShapesWidget.colors.textColorOnBg
                font.family: nayoriDateShapesWidget.appearance.font.family.main
                font.pixelSize: Math.round(72)
                font.variableAxes: ({ "wght": 900, "wdth": 112, "ROND": 100, "opsz": 144 })
                fontSizeMode: Text.Fit
                minimumPixelSize: 28
                verticalAlignment: Text.AlignBottom
                renderType: Text.QtRendering
            }

            Rectangle {
                id: monthChip
                x: root.padding
                anchors.top: weekday.bottom
                anchors.topMargin: 8
                width: monthRow.implicitWidth + 30
                height: 38
                radius: nayoriDateShapesWidget.appearance.rounding.full
                color: nayoriDateShapesWidget.colors.pillFillColor

                Row {
                    id: monthRow
                    anchors.centerIn: parent
                    spacing: 8

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.locale.toString(cal.today, "MMMM")
                        color: nayoriDateShapesWidget.colors.textColorOnPillFill
                        font.pixelSize: Math.round(nayoriDateShapesWidget.appearance.font.pixelSize.larger)
                        font.variableAxes: ({ "wght": 650, "wdth": 100, "ROND": 100 })
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.today.getFullYear()
                        color: nayoriDateShapesWidget.colors.textColorOnPillFill
                        opacity: 0.7
                        font.family: nayoriDateShapesWidget.appearance.font.family.monospace
                        font.pixelSize: Math.round(nayoriDateShapesWidget.appearance.font.pixelSize.smaller)
                    }
                }
            }

            // -- The week as shapes --
            Row {
                visible: root.showWeekShapes
                x: root.padding + 2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.padding
                height: root.todayDot
                spacing: root.weekGap

                Repeater {
                    model: cal.currentWeek

                    delegate: Item {
                        id: dot
                        required property var modelData
                        readonly property bool today: cal.isToday(dot.modelData)
                        readonly property bool past: dot.modelData < cal.today && !dot.today
                        width: dot.today ? root.todayDot : root.weekDot
                        height: root.todayDot

                        MaterialShape {
                            anchors.centerIn: parent
                            implicitSize: dot.today ? root.todayDot : root.weekDot
                            shape: dot.today ? MaterialShape.Shape.Sunny : MaterialShape.Shape.Circle
                            color: dot.today || dot.past ? nayoriDateShapesWidget.colors.accentColor : nayoriDateShapesWidget.colors.pillBgColor
                        }
                    }
                }
            }
        }
    }
}
