import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts





AbstractBackgroundWidget {
    readonly property var nayoriGridCardClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "grid_card_clock"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriGridCardClockWidget.config.options.lock.centerWidget === "grid_card_clock")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriGridCardClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriGridCardClockWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property real contentScale: (nayoriGridCardClockWidget.config.options.background.widgets.grid_card_clock.widgetSize ?? 100) / 100.0
    implicitWidth: 240 * contentScale
    implicitHeight: 240 * contentScale

    // -- Colors (WidgetColorScheme) --
    property color colCardBg: nayoriGridCardClockWidget.colors.cardBgColor
    property color colText: nayoriGridCardClockWidget.colors.textColorOnBg
    property color colTextSecondary: nayoriGridCardClockWidget.colors.subtextColorOnBg
    property color colPillBg: nayoriGridCardClockWidget.colors.innerShapeColor

    StyledDropShadow {
        target: clockBgShape
        visible: nayoriGridCardClockWidget.config.options.background.widgets.enableShadows ?? true
    }

    Item {
        anchors.centerIn: parent
        width: 240
        height: 240
        scale: root.contentScale

        Rectangle {
            id: clockBgShape
            anchors.fill: parent
            radius: nayoriGridCardClockWidget.appearance.rounding.large
            color: nayoriGridCardClockWidget.colors.tintBackground(root.colCardBg)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                // Hours
                StyledText {
                    text: nayoriGridCardClockWidget.dateTime.time.split(":")[0].padStart(2, "0")
                    color: root.colText
                    font.family: nayoriGridCardClockWidget.appearance.font.family.main
                    font.pixelSize: Math.round(210)
                    font.weight: Font.Normal
                    font.variableAxes: ({ "wdth": 25 })
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                }

                // Minutes & AM/PM Column
                ColumnLayout {
                    spacing: 4
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    // Minutes
                    StyledText {
                        text: nayoriGridCardClockWidget.dateTime.time.split(":")[1].split(" ")[0].padStart(2, "0")
                        color: root.colTextSecondary
                        font.family: nayoriGridCardClockWidget.appearance.font.family.main
                        font.pixelSize: Math.round(100)
                        font.weight: Font.Normal
                        font.variableAxes: ({ "wdth": 25 })
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                    }

                    // AM/PM Pill
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.maximumWidth: 64
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                        color: root.colPillBg
                        radius: nayoriGridCardClockWidget.appearance.rounding.normal

                        StyledText {
                            anchors.centerIn: parent
                            text: nayoriGridCardClockWidget.dateTime.time.includes("PM") ? "PM" : "AM"
                            color: root.colText
                            font.family: nayoriGridCardClockWidget.appearance.font.family.main
                            font.pixelSize: Math.round(32)
                            font.variableAxes: ({ "wdth": 25, "wght": 600 })
                        }
                    }
                }
            }
        }
    }
}
