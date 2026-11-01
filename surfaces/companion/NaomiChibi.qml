pragma ComponentBehavior: Bound
import QtQuick

// Hand-edited 200px frames, drawn without interpolation.
Item {
    id: root
    property bool active: true
    property bool animationsEnabled: true
    property var audioReaction: null
    readonly property string consumerKey: "naomi-chibi-" + String(root)
    readonly property bool musicActive: running && audioReaction && audioReaction.playing && audioReaction.available
    property real headAngle: 0
    property int beatDirection: 1
    function updateConsumer() {
        if (audioReaction) audioReaction.consumer(consumerKey, running)
    }
    function resetHead() {
        headReturn.stop()
        headMotion.stop()
        headAngle = 0
        beatDirection = 1
    }
    function musicBeat(strength) {
        if (!musicActive || !isFinite(strength) || strength <= 0) return
        beatDirection = -beatDirection
        headMotion.stop()
        headMotion.to = beatDirection * (1.5 + 2 * Math.min(1, strength))
        headMotion.start()
        headReturn.restart()
    }
    onMusicActiveChanged: if (!musicActive) resetHead()
    onAudioReactionChanged: updateConsumer()
    Component.onCompleted: updateConsumer()
    Component.onDestruction: if (audioReaction) audioReaction.consumer(consumerKey, false)
    Connections {
        target: root.audioReaction
        function onBeat(strength) { root.musicBeat(strength) }
    }
    NumberAnimation { id: headMotion; target: root; property: "headAngle"; duration: 180; easing.type: Easing.InOutSine }
    Timer {
        id: headReturn
        interval: 400
        onTriggered: { headMotion.stop(); headMotion.to = 0; headMotion.start() }
    }
    property real pet: 0
    property bool closedEyes: false
    property int breathFrame: 0
    property int blinkInterval: 5000
    // The frames share visible horizontal bounds [11, 180) within the 200px canvas.
    property string alignment: "center"
    readonly property bool running: active && visible && animationsEnabled
    readonly property real fit: Math.min(width, height) / 200
    readonly property rect headRect: Qt.rect(stage.x + 54 * fit, stage.y + 10 * fit, 90 * fit, 73 * fit)
    readonly property point bubbleAnchor: Qt.point(stage.x + 100 * fit, stage.y + 10 * fit)
    readonly property bool ready: sprite.status === Image.Ready
    readonly property bool failed: sprite.status === Image.Error
    onRunningChanged: {
        updateConsumer()
        if (!running) { blink.stop(); closedEyes = false; breathFrame = 0; resetHead() }
    }
    Timer {
        interval: root.blinkInterval; repeat: true; running: root.running && root.pet < 0.25
        onTriggered: blink.restart()
    }
    SequentialAnimation {
        id: blink
        ScriptAction { script: root.closedEyes = true }
        PauseAnimation { duration: 150 }
        ScriptAction { script: root.closedEyes = false }
    }
    Timer {
        interval: 1700; repeat: true; running: root.running
        onTriggered: root.breathFrame = 1 - root.breathFrame
    }
    Item {
        id: stage
        width: 200; height: 200
        x: root.alignment === "right" ? root.width - 180 * root.fit
            : root.alignment === "left" ? -11 * root.fit
            : (root.width - width * root.fit) / 2
        y: root.height - height * root.fit
        scale: root.fit
        transformOrigin: Item.TopLeft
        Item {
            width: 200; height: 200
            y: -root.breathFrame
            Item {
                y: 82; width: 200; height: 118; clip: true
                Image {
                    y: -82; width: 200; height: 200
                    source: sprite.source; smooth: false; mipmap: false
                }
            }
            Item {
                width: 200; height: 82; clip: true
                transform: Rotation { origin.x: 100; origin.y: 78; angle: root.headAngle }
                Image {
                    id: sprite
                    width: 200; height: 200
                    source: root.closedEyes || root.pet > 0.25 ? "../../assets/naomi/chibi/blink.png" : "../../assets/naomi/chibi/idle.png"
                    smooth: false; mipmap: false
                }
            }
        }
    }
}
