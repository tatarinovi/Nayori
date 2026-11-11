import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick




Item {
    readonly property var nayoriConcentricComplication: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property string type: "battery" // "battery" | "weather_temp" | "none"
    property color textColor: nayoriConcentricComplication.colors.textColorOnBg
    property color subtextColor: nayoriConcentricComplication.colors.subtextColorOnBg
    property color accentColor: nayoriConcentricComplication.colors.accentColor
    property color pillBg: nayoriConcentricComplication.colors.pillBgColor

    implicitWidth: parent.width * 0.18
    implicitHeight: parent.width * 0.09

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.pillBg
        opacity: 0.85

        Row {
            anchors.centerIn: parent
            spacing: 3

            // Battery
            MaterialSymbol {
                visible: root.type === "battery"
                text: nayoriConcentricComplication.battery.isCharging ? "battery_charging_full" : "battery_std"
                iconSize: Math.round(parent.parent.height * 0.55)
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: root.type === "battery"
                text: nayoriConcentricComplication.battery.available ? Math.round(nayoriConcentricComplication.battery.percentage * 100) + "%" : "—"
                color: nayoriConcentricComplication.colors.textColorOnPillTrack
                font.pixelSize: Math.round(parent.parent.height * 0.50)
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }

            // Weather Temp
            MaterialSymbol {
                visible: root.type === "weather_temp"
                text: "device_thermostat"
                iconSize: Math.round(parent.parent.height * 0.55)
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: root.type === "weather_temp"
                text: (nayoriConcentricComplication.weather.data.temp || "--") + "°"
                color: nayoriConcentricComplication.colors.textColorOnPillTrack
                font.pixelSize: Math.round(parent.parent.height * 0.50)
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
