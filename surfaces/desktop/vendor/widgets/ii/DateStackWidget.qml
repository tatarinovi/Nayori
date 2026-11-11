import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick





/*
 * Date Stack (1x1). The day of the month, tall and condensed, set on a big
 * primary cookie that morphs to a twelve-sided one under the pointer; the
 * weekday above, the month on a chip that overlaps the cookie's foot.
 */
AbstractBackgroundWidget {
    readonly property var nayoriDateStackWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "calendar_date_stack"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriDateStackWidget.config.options.lock.centerWidget === "calendar_date_stack")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriDateStackWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriDateStackWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriDateStackWidget.config.options?.background?.widgets?.calendar_date_stack ?? ({})
    readonly property real contentScale: (root.options?.widgetSize ?? 100) / 100.0
    readonly property bool showShape: root.options?.showShape ?? true
    readonly property bool showWeekNumber: root.options?.showWeekNumber ?? true

    // -- Geometry (design units) --
    readonly property real designSize: 240
    readonly property real padding: 18
    readonly property real shapeSize: 158
    readonly property real dayFigureSize: 112
    readonly property real chipHeight: 36

    implicitWidth: root.designSize * root.contentScale
    implicitHeight: root.designSize * root.contentScale

    CalendarWidgetData {
        id: cal
    }

    Item {
        anchors.centerIn: parent
        width: root.designSize
        height: root.designSize
        scale: root.contentScale

        HoverHandler {
            id: hover
        }

        StyledRectangularShadow {
            target: card
            visible: nayoriDateStackWidget.config.options.background.widgets.enableShadows ?? true
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: nayoriDateStackWidget.appearance.rounding.large
            color: nayoriDateStackWidget.colors.tintBackground(nayoriDateStackWidget.colors.cardBgColor)

            StyledText {
                id: weekday
                x: root.padding
                y: root.padding - 2
                width: parent.width - root.padding * 2 - (weekBadge.visible ? weekBadge.width + 8 : 0)
                text: cal.locale.toString(cal.today, "dddd")
                color: nayoriDateStackWidget.colors.textColorOnBg
                font.family: nayoriDateStackWidget.appearance.font.family.title
                font.pixelSize: Math.round(nayoriDateStackWidget.appearance.font.pixelSize.larger)
                font.variableAxes: ({ "wght": 650, "ROND": 100 })
                elide: Text.ElideRight
            }

            StyledText {
                id: weekBadge
                visible: root.showWeekNumber
                anchors.right: parent.right
                anchors.rightMargin: root.padding
                anchors.verticalCenter: weekday.verticalCenter
                text: nayoriDateStackWidget.translation.tr("W%1").arg(cal.weekNumber(cal.today))
                color: nayoriDateStackWidget.colors.subtextColorOnBg
                font.family: nayoriDateStackWidget.appearance.font.family.monospace
                font.pixelSize: Math.round(nayoriDateStackWidget.appearance.font.pixelSize.smaller)
                font.letterSpacing: 1
            }

            MaterialShape {
                id: dayShape
                visible: root.showShape
                anchors.horizontalCenter: parent.horizontalCenter
                y: 46
                implicitSize: root.shapeSize
                shape: hover.hovered ? MaterialShape.Shape.Cookie12Sided : MaterialShape.Shape.Cookie9Sided
                color: nayoriDateStackWidget.colors.accentColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: dayShape.verticalCenter
                anchors.verticalCenterOffset: -2
                text: cal.locale.toString(cal.today, "dd")
                color: root.showShape ? nayoriDateStackWidget.colors.onAccentColor : nayoriDateStackWidget.colors.accentColor
                font.family: nayoriDateStackWidget.appearance.font.family.main
                font.pixelSize: Math.round(root.dayFigureSize)
                font.variableAxes: ({ "wght": 820, "wdth": 28, "ROND": 100, "opsz": 144 })
                renderType: Text.QtRendering
            }

            // Month chip, overlapping the cookie's foot
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.padding - 4
                width: Math.min(chipRow.implicitWidth + 32, parent.width - root.padding * 2)
                height: root.chipHeight
                radius: nayoriDateStackWidget.appearance.rounding.full
                color: nayoriDateStackWidget.colors.pillFillColor

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 8

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.locale.toString(cal.today, "MMMM")
                        color: nayoriDateStackWidget.colors.textColorOnPillFill
                        font.pixelSize: Math.round(nayoriDateStackWidget.appearance.font.pixelSize.normal)
                        font.variableAxes: ({ "wght": 650, "wdth": 100, "ROND": 100 })
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.today.getFullYear()
                        color: nayoriDateStackWidget.colors.textColorOnPillFill
                        opacity: 0.7
                        font.family: nayoriDateStackWidget.appearance.font.family.monospace
                        font.pixelSize: Math.round(nayoriDateStackWidget.appearance.font.pixelSize.smaller)
                    }
                }
            }
        }
    }
}
