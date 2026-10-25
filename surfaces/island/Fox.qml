import QtQuick
import "../../services/island"

// Independent controller channels drive the existing resting silhouette.
Item {
    id: root
    required property var tokens
    property bool reducedMotion: false
    property bool active: true
    property real cpuInput: cpu.load
    property var audioReaction: null
    property bool unread: false
    property bool hovered: pointer.hovered
    property point hoverPosition: pointer.point.position
    property bool testMode: false
    property alias controller: behavior
    readonly property string consumerKey: "fox-" + String(root)
    function updateConsumer() {
        if (audioReaction) audioReaction.consumer(consumerKey, active && visible && !reducedMotion && !testMode)
    }
    onTestModeChanged: updateConsumer()
    onActiveChanged: updateConsumer()
    onVisibleChanged: updateConsumer()
    onReducedMotionChanged: updateConsumer()
    onAudioReactionChanged: updateConsumer()
    Component.onCompleted: updateConsumer()
    Component.onDestruction: { if (audioReaction) audioReaction.consumer(consumerKey, false) }
    readonly property color ink: tokens.color.text
    readonly property color backgroundInk: tokens.color.background
    implicitWidth: 52
    implicitHeight: 30
    Cpu { id: cpu; active: root.active && root.visible && !root.testMode }
    FoxController {
        id: behavior
        cpu: root.cpuInput
        active: root.active && root.visible
        reducedMotion: root.reducedMotion
        unread: root.unread
        playing: root.audioReaction ? root.audioReaction.playing : false
        audioAvailable: root.audioReaction ? root.audioReaction.available : false
        energy: root.audioReaction ? root.audioReaction.energy : 0
        hovered: root.hovered
        pointerX: Math.max(-1, Math.min(1, root.hoverPosition.x / root.width * 2 - 1))
        pointerY: Math.max(-1, Math.min(1, root.hoverPosition.y / root.height * 2 - 1))
        onPoseChanged: drawing.requestPaint()
    }
    Connections {
        target: root.audioReaction
        function onBeat(strength) { if (root.active && root.visible && !root.reducedMotion) behavior.beat(strength) }
    }
    HoverHandler { id: pointer }
    onInkChanged: drawing.requestPaint()
    onBackgroundInkChanged: drawing.requestPaint()
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top
        width: 5; height: 5; radius: 2.5
        color: root.tokens.color.accent
        visible: behavior.pose.marker
    }
    Canvas {
        id: drawing
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const scale = Math.min(width / 65, height / 36)
            ctx.translate((width - 65 * scale) / 2, (height - 36 * scale) / 2)
            ctx.scale(scale, scale)
            const pose = behavior.pose
            const breath = pose.breath
            const look = pose.head
            const tail = pose.tail
            ctx.fillStyle = root.ink

            // Belly and tucked paws stay grounded; only the back rises.
            ctx.beginPath()
            ctx.moveTo(17, 29)
            ctx.bezierCurveTo(16, 20 - breath, 28, 17 - breath, 37, 19 - breath)
            ctx.bezierCurveTo(46, 19, 50, 25, 48, 29)
            ctx.lineTo(54, 29); ctx.lineTo(55, 31)
            ctx.lineTo(23, 32); ctx.closePath(); ctx.fill()

            // Broad brush curls along the flank, occasionally flicking its tip.
            ctx.beginPath()
            ctx.moveTo(35, 28)
            ctx.bezierCurveTo(22, 31, 12, 25, 5, 18 + tail)
            ctx.lineTo(10, 19 + tail)
            ctx.lineTo(8, 14 + tail)
            ctx.bezierCurveTo(20, 17 + tail * 0.4, 23, 25, 39, 27)
            ctx.bezierCurveTo(45, 28, 43, 33, 34, 33)
            ctx.bezierCurveTo(22, 34, 14, 29, 11, 25 + tail * 0.4)
            ctx.bezierCurveTo(22, 30, 29, 30, 35, 28)
            ctx.fill()

            // The fox lifts its muzzle to sniff, then rests it on its paws.
            ctx.save()
            ctx.translate(43, 26)
            ctx.rotate(-look * 0.1 + pose.y * 0.08)
            ctx.translate(-43 + pose.x * 1.5, -26 - look * 1.8 + pose.y)
            ctx.beginPath()
            ctx.moveTo(40, 26)
            ctx.lineTo(40, 13)
            ctx.lineTo(46, 19)
            ctx.lineTo(51, 12)
            ctx.lineTo(53, 22)
            ctx.lineTo(62, 25)
            ctx.lineTo(56, 29)
            ctx.lineTo(44, 29)
            ctx.closePath(); ctx.fill()
            ctx.strokeStyle = root.backgroundInk
            ctx.lineWidth = 1.2
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.moveTo(49 + pose.x * 0.5, 23 + pose.y * 0.3)
            ctx.lineTo(51 + pose.x * 0.5, 23.9 + pose.y * 0.3)
            ctx.stroke()
            ctx.restore()

        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
