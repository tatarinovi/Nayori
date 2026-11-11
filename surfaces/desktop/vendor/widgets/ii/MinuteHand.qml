import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.




import QtQuick

Item {
    readonly property var nayoriMinuteHand: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    required property int clockMinute
    property string style: "medium"
    property real handLength: 95
    property real handWidth: style === "bold" ? 20 : style === "medium" ? 12 : 5
    property color color: nayoriMinuteHand.colors.successColor

    rotation: -90 + (360 / 60) * root.clockMinute
    Behavior on rotation {
        animation: RotationAnimation {
            direction: RotationAnimation.Clockwise
            duration: (nayoriMinuteHand && nayoriMinuteHand.reducedMotion ? 0 : 300)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: nayoriMinuteHand.appearance.animationCurves.emphasized
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: {
            let position = parent.width / 2 - root.handWidth / 2;
            if (root.style === "classic") position -= 15;
            return position;
        }
        width: root.handLength
        height: root.handWidth

        radius: root.style === "classic" ? 2 : root.handWidth / 2
        color: root.color

        Behavior on height {
            NumberAnimation { duration: nayoriMinuteHand.motionDuration; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            NumberAnimation { duration: nayoriMinuteHand.motionDuration; easing.type: Easing.OutCubic }
        }
    }
}
