import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.





import QtQuick

Item {
    readonly property var nayoriSecondHand: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    required property int clockSecond
    property real handWidth: 2
    property real handLength: 95
    property real dotSize: 20
    property string style: "hide"
    property color color: nayoriSecondHand.colors.onAccentColor

    rotation: (360 / 60 * clockSecond) + 90

    Behavior on rotation {
        enabled: nayoriSecondHand.config.options.background.widgets.clock_cookie.constantlyRotate // Animating every second is expensive...
        animation: RotationAnimation {
            direction: RotationAnimation.Clockwise
            duration: (nayoriSecondHand && nayoriSecondHand.reducedMotion ? 0 : 1000) // 1 second
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 10 + (root.style === "dot" ? root.dotSize : 0)
        }
        implicitWidth: root.style === "dot" ? root.dotSize : root.handLength
        implicitHeight: root.style === "dot" ? root.dotSize : root.handWidth
        radius: Math.min(width, height) / 2
        color: root.color
        Behavior on implicitHeight {
            NumberAnimation { duration: nayoriSecondHand.motionDuration; easing.type: Easing.OutCubic }
        }
        Behavior on implicitWidth {
            NumberAnimation { duration: nayoriSecondHand.motionDuration; easing.type: Easing.OutCubic }
        }
    }

    // Classic style dot in the middle of the hand
    FadeLoader {
        id: classicDotLoader
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        shown: root.style === "classic"
        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 40
            }
            implicitWidth: root.style === "classic" ? 14 : 0
            implicitHeight: implicitWidth
            color: root.color
            radius: nayoriSecondHand.appearance.rounding.small

            Behavior on implicitWidth {
                NumberAnimation { duration: nayoriSecondHand.motionDuration; easing.type: Easing.OutCubic }
            }
        }
    }
}
