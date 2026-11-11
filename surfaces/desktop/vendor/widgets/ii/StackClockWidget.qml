import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick





/*
 * Stack Clock (1x2). The four digits of the time stacked down the card, set
 * wide, with a weight ramp from the top digit to the bottom one (or the other
 * way). Between the hours and the minutes runs a thin band: a sunny shape,
 * the weekday and day in monospace, and AM/PM on a 12-hour clock.
 */
AbstractBackgroundWidget {
    readonly property var nayoriStackClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_type_stack"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriStackClockWidget.config.options.lock.centerWidget === "clock_type_stack")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriStackClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriStackClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriStackClockWidget.config.options?.background?.widgets?.clock_type_stack ?? ({})
    readonly property real contentScale: (root.options?.widgetSize ?? 100) / 100.0
    readonly property bool heavyTop: root.options?.heavyTop ?? true

    // -- Geometry (design units) --
    readonly property real designWidth: 240
    readonly property real designHeight: 492
    readonly property real padding: 18
    readonly property real bandHeight: 34
    readonly property real digitStep: (root.designHeight - root.padding * 2 - root.bandHeight) / 4
    readonly property real digitSize: Math.round(root.digitStep * 1.24)
    // Where a digit's cap top sits inside its Text box, as a share of the size.
    readonly property real capOffset: 0.23
    readonly property var weights: root.heavyTop ? [920, 680, 420, 150] : [150, 420, 680, 920]

    implicitWidth: root.designWidth * root.contentScale
    implicitHeight: root.designHeight * root.contentScale

    readonly property date now: nayoriStackClockWidget.dateTime.clock.date
    readonly property string digits: nayoriStackClockWidget.dateTime.hours.padStart(2, "0") + nayoriStackClockWidget.dateTime.minutes

    Item {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: root.contentScale

        TypeClockFrame {
            anchors.fill: parent
            showBackground: root.options?.showBackground ?? true
            textShadow: root.options?.textShadow ?? true

            Repeater {
                model: 4

                delegate: Text {
                    required property int index
                    readonly property real slotTop: root.padding + index * root.digitStep + (index >= 2 ? root.bandHeight : 0)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: slotTop + (root.digitStep - root.digitSize * 0.74) / 2 - root.digitSize * root.capOffset
                    text: root.digits.charAt(index)
                    color: index < 2 ? nayoriStackClockWidget.colors.accentColor : nayoriStackClockWidget.colors.textColorOnBg
                    font.family: nayoriStackClockWidget.appearance.font.family.main
                    font.pixelSize: Math.round(root.digitSize)
                    font.variableAxes: ({ "wght": root.weights[index], "wdth": 151, "ROND": 100, "opsz": 144 })
                    renderType: Text.QtRendering
                }
            }

            // The band between hours and minutes
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.padding + root.digitStep * 2 + (root.bandHeight - height) / 2
                height: 22
                spacing: 8

                MaterialShape {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 20
                    shape: MaterialShape.Shape.Sunny
                    color: nayoriStackClockWidget.colors.accentColor
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.locale().toString(root.now, "ddd dd").replace(".", "").toUpperCase()
                    color: nayoriStackClockWidget.colors.subtextColorOnBg
                    font.family: nayoriStackClockWidget.appearance.font.family.monospace
                    font.pixelSize: Math.round(nayoriStackClockWidget.appearance.font.pixelSize.smaller)
                    font.letterSpacing: 1.5
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: nayoriStackClockWidget.dateTime.use12HourClock
                    text: nayoriStackClockWidget.dateTime.meridiem.toUpperCase()
                    color: nayoriStackClockWidget.colors.accentColor
                    font.family: nayoriStackClockWidget.appearance.font.family.monospace
                    font.pixelSize: Math.round(nayoriStackClockWidget.appearance.font.pixelSize.smaller)
                    font.letterSpacing: 1.5
                }
            }
        }
    }
}
