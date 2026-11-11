import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.





import QtQuick

Item {
    readonly property var nayoriDots: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real implicitSize: 12
    property real margins: 10
    property color color: nayoriDots.colors.textColorOnBg

    Repeater {
        model: 12

        Item {
            required property int index
            anchors.fill: parent // Ensures rotation works properly
            rotation: 360 / 12 * index

            Rectangle {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.margins
                }
                implicitWidth: root.implicitSize
                implicitHeight: implicitWidth
                radius: implicitWidth / 2
                color: root.color
            }
        }
    }
}
