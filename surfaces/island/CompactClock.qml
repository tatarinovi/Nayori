pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Rectangle {
    id: root
    required property var tokens
    property bool showing: false
    property bool active: true
    visible: showing && reveal > 0.001
    height: 48
    radius: height / 2
    width: lyricClockText.implicitWidth + root.tokens.spacing.medium * 2
    color: root.tokens.material.island
    border.width: 1
    border.color: root.tokens.color.border
    antialiasing: true
    property real reveal: showing ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    opacity: reveal
    transform: Translate {
        x: root.tokens.motion.off ? 0 : (1 - root.reveal) * root.tokens.spacing.small
    }
    SystemClock {
        id: lyricClockTime
        precision: SystemClock.Seconds
        enabled: root.active && root.visible
    }
    Text {
        id: lyricClockText
        anchors.centerIn: parent
        text: Qt.formatTime(lyricClockTime.date, "HH:mm:ss")
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: 16
        font.weight: root.tokens.type.body.weight
        font.letterSpacing: 0.4
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }
}
