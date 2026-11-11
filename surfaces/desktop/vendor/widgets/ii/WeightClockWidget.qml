import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick





/*
 * Weight Clock (1x1). Heavy hours stacked over the minutes, whose weight is
 * the hour's progress: a hairline at :00, as heavy as the hours by :59. The
 * axis eases on every minute instead of stepping. Weekday, day and month sit
 * stacked in monospace beside the figures.
 */
AbstractBackgroundWidget {
    readonly property var nayoriWeightClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_type_weight"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriWeightClockWidget.config.options.lock.centerWidget === "clock_type_weight")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriWeightClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriWeightClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriWeightClockWidget.config.options?.background?.widgets?.clock_type_weight ?? ({})
    readonly property real contentScale: (root.options?.widgetSize ?? 100) / 100.0
    readonly property bool weightFollowsMinutes: root.options?.weightFollowsMinutes ?? true

    // -- Geometry (design units) --
    readonly property real designSize: 240
    readonly property real padding: 18
    readonly property real figureSize: 118
    // Baseline-to-baseline of the two figure lines, tighter than the font's own.
    readonly property real lineStep: 96
    readonly property real heavyWeight: 900
    readonly property real lightWeight: 90
    readonly property real figureWidth: 62

    implicitWidth: root.designSize * root.contentScale
    implicitHeight: root.designSize * root.contentScale

    readonly property date now: nayoriWeightClockWidget.dateTime.clock.date
    readonly property real hourProgress: root.now.getMinutes() / 59
    // Eased copy of the progress, so the weight glides into each new minute.
    property real easedProgress: root.hourProgress
    Behavior on easedProgress {
        enabled: !nayoriWeightClockWidget.appearance.reducedMotion
        NumberAnimation { duration: nayoriWeightClockWidget.motionDuration; easing.type: Easing.OutCubic }
    }
    readonly property real minuteWeight: root.weightFollowsMinutes
        ? root.lightWeight + (root.heavyWeight - root.lightWeight) * root.easedProgress
        : 260

    Item {
        anchors.centerIn: parent
        width: root.designSize
        height: root.designSize
        scale: root.contentScale

        TypeClockFrame {
            anchors.fill: parent
            showBackground: root.options?.showBackground ?? true
            textShadow: root.options?.textShadow ?? true

            Text {
                id: hoursText
                x: root.padding - 4
                y: root.padding - 30
                text: nayoriWeightClockWidget.dateTime.hours
                color: nayoriWeightClockWidget.colors.accentColor
                font.family: nayoriWeightClockWidget.appearance.font.family.main
                font.pixelSize: Math.round(root.figureSize)
                font.variableAxes: ({ "wght": root.heavyWeight, "wdth": root.figureWidth, "ROND": 100, "opsz": 144 })
                renderType: Text.QtRendering
            }

            Text {
                x: hoursText.x
                y: hoursText.y + root.lineStep
                text: nayoriWeightClockWidget.dateTime.minutes
                color: nayoriWeightClockWidget.colors.textColorOnBg
                font.family: nayoriWeightClockWidget.appearance.font.family.main
                font.pixelSize: Math.round(root.figureSize)
                font.variableAxes: ({ "wght": Math.round(root.minuteWeight / 20) * 20, "wdth": root.figureWidth, "ROND": 100, "opsz": 144 })
                renderType: Text.QtRendering
            }

            // Date, stacked in monospace down the right edge
            Column {
                anchors.right: parent.right
                anchors.rightMargin: root.padding
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.padding - 2
                spacing: 0

                Repeater {
                    model: [
                        Qt.locale().toString(root.now, "ddd").replace(".", "").toUpperCase(),
                        Qt.locale().toString(root.now, "dd"),
                        Qt.locale().toString(root.now, "MMM").replace(".", "").toUpperCase()
                    ]

                    delegate: StyledText {
                        required property string modelData
                        required property int index
                        anchors.right: parent.right
                        text: modelData
                        color: index === 1 ? nayoriWeightClockWidget.colors.textColorOnBg : nayoriWeightClockWidget.colors.subtextColorOnBg
                        font.family: nayoriWeightClockWidget.appearance.font.family.monospace
                        font.pixelSize: Math.round(index === 1 ? nayoriWeightClockWidget.appearance.font.pixelSize.larger : nayoriWeightClockWidget.appearance.font.pixelSize.smaller)
                        font.letterSpacing: 1.5
                    }
                }
            }

            StyledText {
                visible: nayoriWeightClockWidget.dateTime.use12HourClock
                anchors.right: parent.right
                anchors.rightMargin: root.padding
                y: root.padding
                text: nayoriWeightClockWidget.dateTime.meridiem.toUpperCase()
                color: nayoriWeightClockWidget.colors.accentColor
                font.family: nayoriWeightClockWidget.appearance.font.family.monospace
                font.pixelSize: Math.round(nayoriWeightClockWidget.appearance.font.pixelSize.small)
                font.letterSpacing: 1.5
            }
        }
    }
}
