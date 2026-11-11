import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.





import QtQuick

Item {
    readonly property var nayoriLines: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real numberSize: 80
    property real margins: 10
    property color color: nayoriLines.colors.textColorOnBg

    property real hourLineSize: 4
    property real minuteLineSize: 2
    property real hourLineLength: 18
    property real minuteLineLength: 7

    property int hours: 12
    property int minutes: 60

    // Full dial style hour lines
    Repeater {
        model: root.hours

        Item {
            required property int index
            rotation: 360 / root.hours * index
            anchors.fill: parent

            Rectangle {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.margins
                }
                implicitWidth: root.hourLineLength
                implicitHeight: root.hourLineSize
                radius: implicitWidth / 2
                color: root.color
            }
        }
    }

    // Minute lines
    Repeater {
        model: root.minutes

        Item {
            required property int index
            rotation: 360 / root.minutes * index
            anchors.fill: parent

            Rectangle {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.margins
                }
                implicitWidth: root.minuteLineLength
                implicitHeight: root.minuteLineSize
                radius: implicitWidth / 2
                color: root.color
            }
        }
    }
}
