import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.






import QtQuick

Item {
    readonly property var nayoriHourMarks: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real implicitSize: 135
    property real markLength: 12
    property real markWidth: 4
    property color color: nayoriHourMarks.colors.accentColor
    property color colOnBackground: nayoriHourMarks.colors.pillFillColor
    property real padding: 8

    Rectangle {
        color: root.color
        anchors.centerIn: parent
        implicitWidth: root.implicitSize
        implicitHeight: root.implicitSize
        radius: width / 2

        // Hour mark lines
        Repeater {
            model: 12

            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 12 * index

                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: root.padding
                    }
                    implicitWidth: root.markLength
                    implicitHeight: root.markWidth

                    radius: width / 2
                    color: root.colOnBackground
                }
            }
        }
    }

}
