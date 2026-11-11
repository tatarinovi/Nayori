import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects






AbstractBackgroundWidget {
    readonly property var nayoriPcBatteryBarsWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "pc_battery_bars"
    readonly property bool showPercentage: nayoriPcBatteryBarsWidget.config.options.background.widgets.pc_battery_bars.showPercentage ?? true
    readonly property bool showStatus: nayoriPcBatteryBarsWidget.config.options.background.widgets.pc_battery_bars.showStatus ?? true

    implicitWidth: 240
    implicitHeight: 240

    // PC Battery system info
    readonly property real batteryPct: Math.round((nayoriPcBatteryBarsWidget.battery.percentage ?? 0) * 100)
    readonly property bool isCharging: nayoriPcBatteryBarsWidget.battery.available && (nayoriPcBatteryBarsWidget.battery.isCharging || nayoriPcBatteryBarsWidget.battery.isPluggedIn)
    readonly property real timeRemainingSec: nayoriPcBatteryBarsWidget.battery.isCharging
        ? (nayoriPcBatteryBarsWidget.battery.timeToFullEffective ?? nayoriPcBatteryBarsWidget.battery.timeToFull ?? 0)
        : (nayoriPcBatteryBarsWidget.battery.isPluggedIn ? 0 : (nayoriPcBatteryBarsWidget.battery.timeToEmpty ?? 0))
    readonly property int hoursRemaining: Math.floor(timeRemainingSec / 3600)
    readonly property string batteryStatus: {
        if (!nayoriPcBatteryBarsWidget.battery.available) return nayoriPcBatteryBarsWidget.translation.tr("Battery unavailable");
        if (nayoriPcBatteryBarsWidget.battery.atChargeCeiling) {
            return nayoriPcBatteryBarsWidget.battery.chargeLimitReached
                ? nayoriPcBatteryBarsWidget.translation.tr("Charge limit reached")
                : nayoriPcBatteryBarsWidget.translation.tr("Fully charged");
        }
        if (root.hoursRemaining > 0)
            return "~ " + root.hoursRemaining + " " + nayoriPcBatteryBarsWidget.translation.tr("hours");
        if (nayoriPcBatteryBarsWidget.battery.isPluggedIn && !nayoriPcBatteryBarsWidget.battery.isCharging)
            return nayoriPcBatteryBarsWidget.translation.tr("Plugged in");
        return nayoriPcBatteryBarsWidget.translation.tr("Calculating...");
    }

    // Charging turns the card a fixed light green, so its bars and text take a
    // fixed dark green: a palette accent is light on a dark theme and vanished
    // against it.
    readonly property color lightGreenCharging: "#c4f3a6"
    readonly property color darkGreenOnCharging: "#1f3a10"

    readonly property color activeCardBg: root.isCharging ? root.lightGreenCharging : nayoriPcBatteryBarsWidget.colors.cardBgColor
    readonly property color activeAccentColor: root.isCharging ? root.darkGreenOnCharging : nayoriPcBatteryBarsWidget.colors.accentColor

    StyledRectangularShadow {
        id: bgShadow
        target: cardBg
        visible: nayoriPcBatteryBarsWidget.config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: cardBg
        anchors.fill: parent
        color: nayoriPcBatteryBarsWidget.colors.tintBackground(root.activeCardBg)
        radius: nayoriPcBatteryBarsWidget.appearance.rounding.windowRounding

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            // Top Header: Charging Bolt + Percentage
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                MaterialSymbol {
                    visible: root.isCharging
                    text: "bolt"
                    iconSize: 26
                    color: root.activeAccentColor
                }

                Text {
                    visible: root.showPercentage
                    text: nayoriPcBatteryBarsWidget.battery.available ? root.batteryPct + "%" : "—"
                    color: root.activeAccentColor
                    font {
                        pixelSize: 34
                        weight: Font.Normal
                        bold: false
                        family: "Google Sans Flex"
                        variableAxes: ({ "wght": 600, "ROND": 100 })
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Center 5 Vertical Bars Container
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 170
                Layout.preferredHeight: 76
                radius: 18
                color: nayoriPcBatteryBarsWidget.colorUtils.applyAlpha(root.activeAccentColor, 0.12)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Repeater {
                        model: 5

                        delegate: Item {
                            id: barDelegate
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property int barIndex: index // 0 to 4
                            readonly property real barThreshold: (barIndex + 1) * 20.0
                            readonly property real prevThreshold: barIndex * 20.0
                            readonly property real currentPct: root.batteryPct

                            // Fill ratio for this specific bar (0.0 to 1.0)
                            readonly property real fillRatio: {
                                if (currentPct >= barThreshold) return 1.0
                                if (currentPct <= prevThreshold) return 0.0
                                return (currentPct - prevThreshold) / 20.0
                            }

                            // Background Track for Bar
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: nayoriPcBatteryBarsWidget.colorUtils.applyAlpha(root.activeAccentColor, 0.15)
                            }

                            // Active Fill Bar (Decreasing height from top to bottom)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * barDelegate.fillRatio
                                radius: 8
                                color: root.activeAccentColor

                                Behavior on height {
                                    NumberAnimation { duration: (nayoriPcBatteryBarsWidget.reducedMotion ? 0 : 400); easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Bottom Estimated Time Text
            Text {
                visible: root.showStatus
                Layout.alignment: Qt.AlignHCenter
                text: root.batteryStatus
                color: nayoriPcBatteryBarsWidget.colorUtils.applyAlpha(root.activeAccentColor, 0.70)
                font {
                    pixelSize: 17
                    weight: Font.Medium
                    family: "Google Sans Flex"
                }
            }
        }
    }
}
