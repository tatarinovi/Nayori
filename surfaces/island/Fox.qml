import QtQuick
import "../../services/island"
import "FoxSprite.js" as Sprite

// Pixel-art kitsune drawn in code (FoxSprite.js): lies, stands or walks. Independent
// controller channels (breath, tail, head, pointer parallax, rest/walk/stride, marker)
// drive it; colours come from tokens only.
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
    // Expanded island: cursor anywhere in it, in this item's coordinates.
    property bool lookActive: false
    property point lookPosition: Qt.point(0, 0)
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
    // Fur is the muted accent (accentSoft) lightened; belly and far legs a middle step,
    // socks, ear tips and nose accentSoft itself (the darkest step that still reads on
    // the graphite island), chest and tail tip cream.
    readonly property color bodyInk: Qt.lighter(tokens.color.accentSoft, 1.45)
    readonly property color lightInk: tokens.color.text
    readonly property color shadeInk: Qt.lighter(tokens.color.accentSoft, 1.12)
    readonly property color darkInk: tokens.color.accentSoft
    readonly property color eyeInk: tokens.color.background
    property var cells: []
    function rebuild() {
        const next = Sprite.render(behavior.pose)
        let same = cells.length === next.length
        for (let i = 0; same && i < next.length; i++) if (cells[i] !== next[i]) same = false
        if (same) return
        cells = next
        drawing.requestPaint()
    }
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
        looking: root.lookActive
        lookX: root.lookPosition.x - root.width / 2
        lookY: root.lookPosition.y - root.height / 2
        onPoseChanged: root.rebuild()
    }
    Connections {
        target: root.audioReaction
        function onBeat(strength) { if (root.active && root.visible && !root.reducedMotion) behavior.beat(strength) }
    }
    HoverHandler { id: pointer }
    onBodyInkChanged: drawing.requestPaint()
    onLightInkChanged: drawing.requestPaint()
    onDarkInkChanged: drawing.requestPaint()
    onShadeInkChanged: drawing.requestPaint()
    onEyeInkChanged: drawing.requestPaint()
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top
        width: 5; height: 5; radius: 2.5
        color: root.tokens.color.accent
        // The cream ring keeps the dot apart from the lavender fur next to it.
        border.width: 1; border.color: root.tokens.color.text
        visible: behavior.pose.marker
    }
    // Cells are painted as whole 1x1 squares (runs per row) with no smoothing, so the
    // sprite stays crisp at 1x and at integer scales.
    Canvas {
        id: drawing
        anchors.fill: parent
        antialiasing: false
        smooth: false
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const scale = Math.min(width / Sprite.W, height / Sprite.H)
            ctx.translate((width - Sprite.W * scale) / 2, (height - Sprite.H * scale) / 2)
            ctx.scale(scale, scale)
            const colors = [null, root.bodyInk, root.lightInk, root.darkInk, root.shadeInk, root.bodyInk, root.lightInk, root.eyeInk]
            const cells = root.cells
            for (let y = 0; y < Sprite.H; y++) {
                let x = 0
                while (x < Sprite.W) {
                    const id = cells[y * Sprite.W + x]
                    let end = x + 1
                    while (end < Sprite.W && cells[y * Sprite.W + end] === id) end++
                    if (id) { ctx.fillStyle = colors[id]; ctx.fillRect(x, y, end - x, 1) }
                    x = end
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: { root.rebuild(); requestPaint() }
    }
}
