pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../../tokens/AccentRoles.js" as AccentRoles

// Haori Naomi. Every PNG keeps the shared 470x1024 canvas from assets/naomi/haori.
// A blink covers the eyes with the closed eyes from the expression sheet. From midnight to 06:00 the sleepy eyes stay on. While a line is showing, the mouth opens and closes. While petted, the eyes close, a small blush from the laugh shows, and the head leans toward the cursor.
Item {
    id: root
    property url assetDirectory: Qt.resolvedUrl("../../assets/naomi/haori/")
    property bool running: true
    property bool active: true
    property bool animationsEnabled: true
    property real pet: 0
    property real petLean: 0
    // A line is on screen. The mouth opens and closes until it goes away.
    property bool speaking: false
    property color accentColor: AccentRoles.authoredRoles().accent
    // -1 follows the system clock. 0–5 is sleepy, matching Naomi's night lines (00:00–05:59).
    property int hourOverride: -1
    property int systemHour: new Date().getHours()
    readonly property bool sleepy: {
        const h = hourOverride >= 0 ? hourOverride : systemHour
        return h >= 0 && h <= 5
    }
    property int blinkInterval: 5000
    readonly property bool idleRunning: running && active && visible && animationsEnabled
    readonly property real fit: Math.min(width / 470, height / 1024) * 0.97
    readonly property real breath: idleRunning ? (1 - Math.cos(breathPhase)) / 2 : 0
    readonly property real bodyY: -2.5 * breath
    readonly property real bodyScale: 1 + 0.01 * breath
    readonly property real sway: 1 + 0.85 * pet
    // One smooth cycle while petted. Hair and ribbons lag the nod so the motion has follow-through.
    readonly property real nod: Math.sin(petPhase * 2 * Math.PI)
    readonly property real hairFollow: Math.sin(petPhase * 2 * Math.PI - 0.65)
    readonly property real ribbonFollow: Math.sin(petPhase * 2 * Math.PI - 1.1)
    readonly property real headAngle: (idleRunning ? 1.5 * Math.sin(headPhase) : 0) + pet * (1.2 + 2.6 * petLean + 3.2 * nod)
    readonly property real frontAngle: (idleRunning ? 0.5 * sway * Math.sin(hairPhase) : 0) + 1.4 * pet * hairFollow
    readonly property real backAngle: (idleRunning ? -0.4 * sway * Math.sin(hairPhase) : 0) - 1.0 * pet * nod
    readonly property real coatAngle: (idleRunning ? 0.55 * Math.sin(clothPhase) : 0) + 0.35 * pet * hairFollow
    readonly property real ribbonAngle: (idleRunning ? 1.35 * sway * Math.sin(clothPhase + 0.8) : 0) + 2.2 * pet * ribbonFollow
    readonly property real blinkShut: (1 - eyesOpen) * (1 - Math.min(pet, 1))
    readonly property point headPivot: Qt.point(194, 185)
    readonly property rect headRect: Qt.rect(stage.x + 70 * fit, stage.y + 8 * fit,
                                              220 * fit, 190 * fit)
    readonly property point bubbleAnchor: Qt.point(stage.x + 190 * fit, stage.y + 4 * fit)
    readonly property var layers: [legs, hairBack, body, clothing, coat, head, cheekBlush, arm, hairFront, hand, ribbons, eyes, eyesClosed, eyesSleepy, eyesHappy, mouth, mouthSmile, mouthTalk]
    readonly property bool ready: layers.every(layer => layer.status === Image.Ready)
    readonly property bool failed: layers.some(layer => layer.status === Image.Error)
    property real breathPhase: 0
    property real headPhase: 0
    property real hairPhase: 0
    property real clothPhase: 0
    property real petPhase: 0
    property real eyesOpen: 1
    property real speech: 0
    property real talkPhase: 0
    property real sleepiness: new Date().getHours() <= 5 ? 1 : 0
    readonly property real talkOpen: speech * (animationsEnabled ? Math.pow(Math.max(0, Math.sin(talkPhase)), 0.4) : 1)
    implicitWidth: 470
    implicitHeight: 1024

    onIdleRunningChanged: if (!idleRunning) {
        blink.stop()
        eyesOpen = 1
        breathPhase = 0
        headPhase = 0
        hairPhase = 0
        clothPhase = 0
        petPhase = 0
        talkPhase = 0
    }
    onSpeakingChanged: speech = speaking ? 1 : 0
    onSleepyChanged: {
        sleepiness = sleepy ? 1 : 0
        if (sleepy) {
            blink.stop()
            eyesOpen = 1
        }
    }
    onPetChanged: if (pet > 0.25) {
        blink.stop()
        eyesOpen = 1
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
    NumberAnimation on clothPhase {
        from: 0; to: 2 * Math.PI; duration: 9400
        loops: Animation.Infinite
        running: root.idleRunning
    }
    NumberAnimation on petPhase {
        from: 0; to: 1; duration: 1500
        loops: Animation.Infinite
        running: root.idleRunning && root.pet > 0.02
    }
    // One syllable: the mouth opens and shuts, and the loop meets at a closed mouth.
    NumberAnimation on talkPhase {
        from: 0; to: Math.PI; duration: 280
        loops: Animation.Infinite
        running: root.idleRunning && root.speech > 0.02
    }
    Behavior on speech {
        enabled: root.animationsEnabled
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }
    Behavior on sleepiness {
        enabled: root.animationsEnabled
        NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.systemHour = new Date().getHours()
    }
    Timer {
        interval: root.blinkInterval
        repeat: true
        running: root.idleRunning && root.pet < 0.25 && !root.sleepy
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
        property point pivot: Qt.point(194, 185)
        anchors.fill: parent
        source: root.assetDirectory.toString() + part + ".png"
        fillMode: Image.Stretch
        smooth: true
        mipmap: true
        transform: Rotation { origin.x: layer.pivot.x; origin.y: layer.pivot.y; angle: layer.angle }
    }
    Item {
        id: stage
        width: 470
        height: 1024
        scale: root.fit
        transformOrigin: Item.TopLeft
        x: (root.width - width * root.fit) / 2
        y: root.height - height * root.fit

        // Legs stay put. Everything above them breathes.
        Layer { id: legs; part: "legs" }
        Item {
            width: 470
            height: 1024
            transform: [
                Scale { origin.x: 231; origin.y: 327; xScale: root.bodyScale; yScale: root.bodyScale },
                Translate { y: (root.fit > 0 ? root.bodyY / root.fit : 0) + root.pet * (2.4 + 7 * root.nod) }
            ]
            Layer { id: hairBack; part: "hair_back"; angle: root.headAngle + root.backAngle }
            Layer { id: body; part: "body" }
            Layer { id: clothing; part: "clothing" }
            Item {
                width: 470
                height: 1024
                transform: Rotation { origin.x: 170; origin.y: 290; angle: root.coatAngle }
                Layer { id: coat; part: "coat" }
                Layer { id: hand; part: "hand" }
                Item {
                    width: 470
                    height: 1024
                    transform: Rotation { origin.x: 342; origin.y: 355; angle: root.ribbonAngle }
                    Layer { id: ribbons; part: "ribbons" }
                }
            }
            Layer { id: head; part: "head"; angle: root.headAngle }
            Layer { id: cheekBlush; part: "face_blush"; angle: root.headAngle; opacity: root.pet }
            Layer { id: arm; part: "arm"; angle: root.headAngle }
            Layer { id: hairFront; part: "hair_front"; angle: root.headAngle + root.frontAngle }
            Layer { id: eyes; part: "eyes"; angle: root.headAngle }
            Layer { id: eyesClosed; part: "face_blink"; angle: root.headAngle; opacity: root.blinkShut * (1 - root.sleepiness) }
            Layer { id: eyesSleepy; part: "face_sleepy"; angle: root.headAngle; opacity: root.sleepiness * (1 - root.pet) }
            Layer { id: eyesHappy; part: "eyes_happy"; angle: root.headAngle; opacity: root.pet }
            Layer { id: mouth; part: "mouth"; angle: root.headAngle; opacity: (1 - root.pet) * (1 - root.talkOpen) }
            Layer { id: mouthSmile; part: "mouth_smile"; angle: root.headAngle; opacity: root.pet * (1 - root.talkOpen) }
            Layer { id: mouthTalk; part: "face_talk"; angle: root.headAngle; opacity: root.talkOpen }
        }
        Repeater {
            model: [
                { sx: 150, sy: 36, size: 7, offset: 0.0, rise: 22 },
                { sx: 214, sy: 24, size: 6, offset: 0.38, rise: 18 },
                { sx: 178, sy: 8, size: 5, offset: 0.7, rise: 16 }
            ]
            delegate: Shape {
                id: spark
                required property var modelData
                readonly property real progress: (root.petPhase + modelData.offset) % 1
                readonly property real sparkSize: modelData.size * (0.55 + 0.6 * Math.sin(Math.PI * progress))
                property real cx: modelData.sx
                property real cy: modelData.sy - modelData.rise * progress
                preferredRendererType: Shape.CurveRenderer
                opacity: root.idleRunning ? root.pet * Math.max(0, Math.sin(Math.PI * progress)) * 0.9 : 0
                visible: opacity > 0.01
                ShapePath {
                    fillColor: root.accentColor
                    strokeColor: "transparent"
                    startX: spark.cx
                    startY: spark.cy - spark.sparkSize
                    PathQuad { x: spark.cx + spark.sparkSize; y: spark.cy; controlX: spark.cx + spark.sparkSize * 0.12; controlY: spark.cy - spark.sparkSize * 0.12 }
                    PathQuad { x: spark.cx; y: spark.cy + spark.sparkSize; controlX: spark.cx + spark.sparkSize * 0.12; controlY: spark.cy + spark.sparkSize * 0.12 }
                    PathQuad { x: spark.cx - spark.sparkSize; y: spark.cy; controlX: spark.cx - spark.sparkSize * 0.12; controlY: spark.cy + spark.sparkSize * 0.12 }
                    PathQuad { x: spark.cx; y: spark.cy - spark.sparkSize; controlX: spark.cx - spark.sparkSize * 0.12; controlY: spark.cy - spark.sparkSize * 0.12 }
                }
            }
        }
    }
}
