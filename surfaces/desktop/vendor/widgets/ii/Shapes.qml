import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.






import QtQuick

Item {
    readonly property var nayoriShapes: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property real implicitSize: 24
    property real margins: 10
    property color color: nayoriShapes.colors.textColorOnBg

    readonly property color accentVibrant: nayoriShapes.colorUtils.mix(root.color, nayoriShapes.colors.accentColor, 0.3)

    Repeater {
        model: 12

        Item {
            required property int index
            readonly property bool isCardinal: index === 0 || index === 3 || index === 6 || index === 9
            anchors.fill: parent
            rotation: 360 / 12 * index

            MaterialShape {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.margins
                }
                implicitWidth: root.implicitSize
                implicitHeight: root.implicitSize
                shapeString: ["Circle", "Pill", "Cookie6Sided", "Cookie9Sided",
                              "Cookie12Sided", "Clover4Leaf", "Clover8Leaf",
                              "Burst", "SoftBurst", "Puffy", "Gem", "Cookie4Sided"][index % 12]
                color: isCardinal ? root.accentVibrant : root.color
            }
        }
    }
}
