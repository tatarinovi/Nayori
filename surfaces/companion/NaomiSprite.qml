pragma ComponentBehavior: Bound
import QtQuick

// MVP from assets/naomi/v3/manifest.json. Every PNG keeps its full 305x1024 canvas.
Item {
    id: root
    property url assetDirectory: Qt.resolvedUrl("../../assets/naomi/v3/")
    property bool running: true
    property bool active: true
    property bool animationsEnabled: true
    property int blinkInterval: 5000
    readonly property bool idleRunning: running && active && visible && animationsEnabled
    readonly property real fit: Math.min(width / 305, height / 1024) * 0.97
    readonly property real breath: idleRunning ? (1 - Math.cos(breathPhase)) / 2 : 0
    readonly property real bodyY: -2.5 * breath
    readonly property real bodyScale: 1 + 0.01 * breath
    readonly property real headAngle: idleRunning ? 1.5 * Math.sin(headPhase) : 0
    readonly property real frontAngle: idleRunning ? 0.45 * Math.sin(hairPhase) : 0
    readonly property real backAngle: idleRunning ? -0.35 * Math.sin(hairPhase) : 0
    readonly property rect headRect: Qt.rect(stage.x + 50 * fit, stage.y + 20 * fit,
                                              185 * fit, 210 * fit)
    readonly property point bubbleAnchor: Qt.point(stage.x + 140 * fit, stage.y + 8 * fit)
    readonly property var layers: [legs, body, hairBack, clothing, head, armRight, armLeft, hairFront, eyes, mouth]
    readonly property bool ready: layers.every(layer => layer.status === Image.Ready)
    readonly property bool failed: layers.some(layer => layer.status === Image.Error)
    property real breathPhase: 0
    property real headPhase: 0
    property real hairPhase: 0
    property real eyesOpen: 1
    implicitWidth: 305
    implicitHeight: 1024

    onIdleRunningChanged: if (!idleRunning) {
        blink.stop()
        eyesOpen = 1
        breathPhase = 0
        headPhase = 0
        hairPhase = 0
    }
    NumberAnimation on breathPhase {
        from: 0; to: 2 * Math.PI; duration: 6000
        loops: Animation.Infinite
        running: root.idleRunning
    }
    NumberAnimation on headPhase {
        from: 0; to: 2 * Math.PI; duration: 7000
        loops: Animation.Infinite
        running: root.idleRunning
    }
    NumberAnimation on hairPhase {
        from: 0; to: 2 * Math.PI; duration: 8200
        loops: Animation.Infinite
        running: root.idleRunning
    }
    Timer {
        interval: root.blinkInterval
        repeat: true
        running: root.idleRunning
        onTriggered: blink.restart()
    }
    SequentialAnimation {
        id: blink
        NumberAnimation { target: root; property: "eyesOpen"; to: 0; duration: 80 }
        PauseAnimation { duration: 90 }
        NumberAnimation { target: root; property: "eyesOpen"; to: 1; duration: 110 }
    }

    component Layer: Image {
        id: layer
        required property string part
        property real angle: 0
        property point pivot: Qt.point(140, 195)
        anchors.fill: parent
        source: root.assetDirectory.toString() + part + ".png"
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        transform: Rotation { origin.x: layer.pivot.x; origin.y: layer.pivot.y; angle: layer.angle }
    }
    Item {
        id: stage
        width: 305
        height: 1024
        scale: root.fit
        transformOrigin: Item.TopLeft
        x: (root.width - width * root.fit) / 2
        y: root.height - height * root.fit

        // Back-to-front order is exactly the manifest's order. Legs never move.
        Layer { id: legs; part: "legs" }
        Item {
            width: 305
            height: 1024
            transform: [
                Scale { origin.x: 160; origin.y: 488; xScale: root.bodyScale; yScale: root.bodyScale },
                Translate { y: root.fit > 0 ? root.bodyY / root.fit : 0 }
            ]
            Layer { id: body; part: "body" }
            Layer { id: hairBack; part: "hair_back"; angle: root.headAngle + root.backAngle }
            Layer { id: clothing; part: "clothing" }
            Layer { id: head; part: "head"; angle: root.headAngle }
            Layer { id: armRight; part: "arm_right" }
            Layer { id: armLeft; part: "arm_left" }
            Layer { id: hairFront; part: "hair_front"; angle: root.headAngle + root.frontAngle; pivot: Qt.point(133, 130) }
            Layer { id: eyes; part: "eyes"; angle: root.headAngle; opacity: root.eyesOpen }
            Layer { id: mouth; part: "mouth"; angle: root.headAngle }
        }
    }
}
