pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    objectName: "compactMediaIsland"
    required property var tokens
    property var player: null
    property bool showing: false
    property real reveal: showing ? 1 : 0
    implicitWidth: 116
    implicitHeight: 48
    width: implicitWidth; height: implicitHeight
    radius: height / 2
    color: tokens.material.island
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true
    visible: showing && reveal > 0.001
    enabled: showing
    opacity: reveal
    transform: Translate { x: root.tokens.motion.off ? 0 : (1 - root.reveal) * -root.tokens.spacing.small }
    Behavior on reveal {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    Row {
        anchors.centerIn: parent
        Repeater {
            model: ["prev", "toggle", "next"]
            delegate: AbstractButton {
                id: control
                required property string modelData
                objectName: "compactMedia_" + modelData
                width: 32; height: 36
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                Accessible.name: modelData === "prev" ? "Предыдущий трек" : modelData === "next" ? "Следующий трек" : root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"
                enabled: !!root.player && (modelData === "prev" ? root.player.canGoPrevious : modelData === "next" ? root.player.canGoNext : root.player.canTogglePlaying)
                background: Rectangle {
                    radius: 8
                    color: control.down || control.hovered ? Qt.alpha(root.tokens.color.surfaceAlt, 0.6) : "transparent"
                    border.width: control.visualFocus ? 1 : 0
                    border.color: root.tokens.color.accent
                }
                contentItem: Item {
                    Glyph {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        name: control.modelData === "toggle" ? (root.player && root.player.isPlaying ? "pause" : "play") : control.modelData
                        ink: root.tokens.color.text
                        opacity: control.enabled ? 1 : 0.35
                    }
                }
                onClicked: {
                    if (!root.player) return
                    if (modelData === "prev") root.player.previous()
                    else if (modelData === "next") root.player.next()
                    else root.player.togglePlaying()
                }
            }
        }
    }
}
