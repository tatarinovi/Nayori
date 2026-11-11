import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.




import QtQuick

Item {
    readonly property var nayoriHourHand: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    required property int clockHour
    required property int clockMinute
    property real handLength: 72
    property real handWidth: 20
    property string style: "fill"
    property color color: nayoriHourHand.colors.accentColor

    property real fillColorAlpha: root.style === "hollow" ? 0 : 1
    Behavior on fillColorAlpha {
        NumberAnimation { duration: nayoriHourHand.motionDuration; easing.type: Easing.OutCubic }
    }

    rotation: -90 + (360 / 12) * (root.clockHour + root.clockMinute / 60)
    Behavior on rotation {
        animation: RotationAnimation {
            direction: RotationAnimation.Clockwise
            duration: (nayoriHourHand && nayoriHourHand.reducedMotion ? 0 : 300)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: nayoriHourHand.appearance.animationCurves.emphasized
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - root.handWidth) / 2 - 15 * (root.style === "classic")
        width: root.handLength
        height: root.style === "classic" ? 8 : root.handWidth
        radius: root.style === "classic" ? 2 : root.handWidth / 2
        color : Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillColorAlpha)
        border.color: root.color
        border.width: 4

        Behavior on x {
            NumberAnimation { duration: nayoriHourHand.motionDuration; easing.type: Easing.OutCubic }
        }
    }
}
