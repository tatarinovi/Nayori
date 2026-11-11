import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.





import QtQuick

Item {
    readonly property var nayoriBigHourNumbers: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real numberSize: 80
    property real margins: 10
    property color color: nayoriBigHourNumbers.colors.textColorOnBg

    property int hours: 12
    property int numbers: 4
    property int fontSize: 80

    Repeater {
        model: root.numbers

        Item {
            id: numberItem
            required property int index
            rotation: 360 / root.numbers * (index + 1)
            anchors.fill: parent

            Item {
                implicitWidth: root.numberSize
                implicitHeight: implicitWidth
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: root.margins
                }
                StyledText {
                    color: root.color
                    anchors.centerIn: parent
                    text: root.hours / root.numbers * (numberItem.index + 1)
                    rotation: -numberItem.rotation

                    font {
                        family: nayoriBigHourNumbers.appearance.font.family.reading
                        pixelSize: root.fontSize
                        weight: Font.Black
                    }
                }
            }
        }
    }
}
