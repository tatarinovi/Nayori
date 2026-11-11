import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick



Item {
    readonly property var nayoriClockFaceAnalog: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 800
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property var fallbackTime: new Date()
    readonly property var currentTime: nayoriClockFaceAnalog.dateTime.hasSeconds ? nayoriClockFaceAnalog.dateTime.now : fallbackTime

    Timer {
        interval: 1000
        running: root.visible && !nayoriClockFaceAnalog.dateTime.hasSeconds
        repeat: true
        onTriggered: root.fallbackTime = new Date()
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(nayoriClockFaceAnalog.pythonTheme.surface0, nayoriClockFaceAnalog.pythonTheme.elementOpacity)

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        Rectangle {
            width: parent.width * 0.045
            height: parent.height * 0.32
            color: nayoriClockFaceAnalog.pythonTheme.text
            anchors.bottom: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Bottom
            rotation: (root.currentTime.getHours() % 12) * 30 + root.currentTime.getMinutes() * 0.5 + root.currentTime.getSeconds() * (0.5 / 60)
            radius: width / 2

            Behavior on rotation {
                RotationAnimation {
                    duration: (nayoriClockFaceAnalog && nayoriClockFaceAnalog.reducedMotion ? 0 : 1000)
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.Linear
                }
            }
        }

        Rectangle {
            width: parent.width * 0.03
            height: parent.height * 0.42
            color: nayoriClockFaceAnalog.pythonTheme.subtext0
            anchors.bottom: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Bottom
            rotation: root.currentTime.getMinutes() * 6 + root.currentTime.getSeconds() * 0.1
            radius: width / 2

            Behavior on rotation {
                RotationAnimation {
                    duration: (nayoriClockFaceAnalog && nayoriClockFaceAnalog.reducedMotion ? 0 : 1000)
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.Linear
                }
            }
        }

        Rectangle {
            width: parent.width * 0.015
            height: parent.height * 0.46
            color: nayoriClockFaceAnalog.pythonTheme.mauve
            anchors.bottom: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Bottom
            rotation: root.currentTime.getSeconds() * 6
            radius: width / 2

            Behavior on rotation {
                RotationAnimation {
                    duration: (nayoriClockFaceAnalog && nayoriClockFaceAnalog.reducedMotion ? 0 : 1000)
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.Linear
                }
            }
        }

        Rectangle {
            width: parent.width * 0.05
            height: width
            color: nayoriClockFaceAnalog.pythonTheme.mauve
            anchors.centerIn: parent
            radius: width / 2
        }
    }
}
