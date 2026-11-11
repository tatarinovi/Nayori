import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick




Item {
    readonly property var nayoriConcentricSubDial: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property string type: "hour" // "hour" | "sunset"
    property color textColor: nayoriConcentricSubDial.colors.textColorOnBg
    property color subtextColor: nayoriConcentricSubDial.colors.subtextColorOnBg
    property color accentColor: nayoriConcentricSubDial.colors.accentColor

    property int hour: nayoriConcentricSubDial.dateTime.clock.hours
    property int minute: nayoriConcentricSubDial.dateTime.clock.minutes

    readonly property real hourRotation: ((hour % 12) * 30) + (minute * 0.5)

    implicitWidth: parent.width * 0.22
    implicitHeight: implicitWidth

    // ── TYPE 1: HOUR SUB-DIAL ──
    Item {
        anchors.fill: parent
        visible: root.type === "hour"

        // Current hour text
        StyledText {
            text: root.hour % 12 === 0 ? 12 : root.hour % 12
            color: root.textColor
            font.pixelSize: Math.round(parent.height * 0.32)
            font.weight: Font.Bold
            anchors.centerIn: parent
        }
    }

    // ── TYPE 2: SUNSET SUB-DIAL ──
    Item {
        anchors.fill: parent
        visible: root.type === "sunset"

        readonly property string sunsetTime: nayoriConcentricSubDial.weather.data.sunset || "—"

        Row {
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                text: "sunny"
                fill: 1
                iconSize: Math.round(root.height * 0.35)
                color: root.textColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: parent.parent.sunsetTime
                color: root.textColor
                font.pixelSize: Math.round(root.height * 0.32)
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
