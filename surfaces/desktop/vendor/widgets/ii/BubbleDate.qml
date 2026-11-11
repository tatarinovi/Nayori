import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.



import QtQuick

Item {
    readonly property var nayoriBubbleDate: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property bool isMonth: false
    property real targetSize: 0
    property alias text: bubbleText.text

    text: Qt.locale().toString(nayoriBubbleDate.dateTime.clock.date, root.isMonth ? "MM" : "d")

    MaterialShape {
        id: bubble
        z: 5
        shape: root.isMonth ? MaterialShape.Shape.Pill : MaterialShape.Shape.Pentagon
        anchors.centerIn: parent
        color: root.isMonth ? nayoriBubbleDate.colors.pillBgColor : nayoriBubbleDate.colors.pillFillColor
        implicitSize: targetSize
    }

    StyledText {
        id: bubbleText
        z: 6
        anchors.centerIn: parent
        color: root.isMonth ? nayoriBubbleDate.colors.textColorOnPillTrack : nayoriBubbleDate.colors.textColorOnPillFill
        font {
            family: nayoriBubbleDate.appearance.font.family.expressive
            pixelSize: 30
            weight: Font.Black
        }
    }
}
