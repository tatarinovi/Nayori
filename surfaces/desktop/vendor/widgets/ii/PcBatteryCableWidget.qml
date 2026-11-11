import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects






AbstractBackgroundWidget {
    readonly property var nayoriPcBatteryCableWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "pc_battery_cable"
    readonly property bool showPercentage: nayoriPcBatteryCableWidget.config.options.background.widgets.pc_battery_cable.showPercentage ?? true
    readonly property bool showChargingIcon: nayoriPcBatteryCableWidget.config.options.background.widgets.pc_battery_cable.showChargingIcon ?? true

    implicitWidth: 240
    implicitHeight: 240

    // PC Battery system info
    readonly property real batteryPct: Math.round((nayoriPcBatteryCableWidget.battery.percentage ?? 0) * 100)
    readonly property bool isCharging: nayoriPcBatteryCableWidget.battery.available && (nayoriPcBatteryCableWidget.battery.isCharging || nayoriPcBatteryCableWidget.battery.isPluggedIn)

    readonly property color cardBgColor: nayoriPcBatteryCableWidget.colors.cardBgColor
    readonly property color fgColor: nayoriPcBatteryCableWidget.colors.textColorOnBg

    StyledRectangularShadow {
        id: bgShadow
        target: cardBg
        visible: nayoriPcBatteryCableWidget.config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: cardBg
        anchors.fill: parent
        color: nayoriPcBatteryCableWidget.colors.tintBackground(root.cardBgColor)
        radius: nayoriPcBatteryCableWidget.appearance.rounding.windowRounding

        Item {
            anchors.fill: parent
            anchors.margins: 0

            // Top-Left Custom Cable Plug & Bolt Icon made using simple Rectangles
            Item {
                id: chargerCableGroup
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 24
                width: 140
                height: 40

                // Horizontal Cable Wire flush to left margin 0
                Rectangle {
                    id: cableWire
                    anchors.left: parent.left
                    anchors.verticalCenter: plugBody.verticalCenter
                    width: 38
                    height: 5
                    color: root.fgColor
                }

                // Charger Plug Body
                Rectangle {
                    id: plugBody
                    anchors.left: cableWire.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 32
                    radius: 6
                    color: root.fgColor
                }

                // Charger Connector Tip (Outline Rectangle seamlessly attached to plug body)
                Rectangle {
                    anchors.left: plugBody.right
                    anchors.verticalCenter: plugBody.verticalCenter
                    anchors.leftMargin: -6
                    width: 22
                    height: 22
                    radius: 6
                    color: "transparent"
                    border.color: root.fgColor
                    border.width: 1
                }

                // Charging Bolt Icon (if charging)
                MaterialSymbol {
                    anchors.left: plugBody.right
                    anchors.leftMargin: 28
                    anchors.verticalCenter: plugBody.verticalCenter
                    visible: root.isCharging && root.showChargingIcon
                    text: "bolt"
                    iconSize: 20
                    color: root.fgColor
                }
            }

            // Bottom-Right Percentage Text (thinner, matching image reference)
            ColumnLayout {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 18
                anchors.bottomMargin: 16
                spacing: 0

                Text {
                    visible: root.showPercentage
                    Layout.alignment: Qt.AlignRight
                    text: nayoriPcBatteryCableWidget.battery.available ? root.batteryPct + "%" : "—"
                    color: root.fgColor
                    font {
                        pixelSize: 42
                        weight: Font.DemiBold
                        bold: false
                        family: "Google Sans Flex"
                        variableAxes: ({ "wght": 600, "RNDS": 100 })
                    }
                }
            }
        }
    }
}
