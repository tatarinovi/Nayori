pragma ComponentBehavior: Bound
import QtQuick

// Hand-edited 200px frames, drawn without interpolation.
Item {
    id: root
    property bool active: true
    property bool animationsEnabled: true
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
    onRunningChanged: if (!running) { blink.stop(); closedEyes = false; breathFrame = 0 }
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
        Image {
            id: sprite
            width: 200; height: 200
            source: root.closedEyes || root.pet > 0.25 ? "../../assets/naomi/chibi/blink.png" : "../../assets/naomi/chibi/idle.png"
            smooth: false
            mipmap: false
            y: -root.breathFrame
        }
    }
}
