import QtQuick
import Quickshell
import "tokens"
import "surfaces/companion"

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool blinkSeen: false
    property bool motionSeen: false
    property bool captured: false
    property bool motionCaptured: false
    property var controller: null
    property real lowestY: 0
    property real largestScale: 1
    function check(ok, message) {
        if (!ok) { console.error("NAOMI_SPRITE_FAIL " + message); Qt.exit(1) }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 300
        implicitHeight: 700
        color: "transparent"
        Tokens { id: theme }
        NaomiCompanion {
            id: companion
            anchors.fill: parent
            tokens: theme
            companionStyle: "layered"
            illustrationWidth: 280
            illustrationHeight: 534
            active: false
            greet: false
        }
    }
    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            const sprite = companion.illustration.renderer
            test.check(!sprite.failed, "PNG layers load without errors")
            if (test.ticks > 430) { test.check(false, "timeout"); return }
            if (test.phase === 0) {
                if (!sprite.ready) return
                test.check(sprite.layers.map(layer => layer.part).join(",") ===
                    "legs,body,hair_back,clothing,head,arm_right,arm_left,hair_front,eyes,mouth", "manifest stacking order")
                test.check(sprite.layers.every(layer => layer.width === 305 && layer.height === 1024 && layer.x === 0 && layer.y === 0),
                    "all ten layers retain the shared canvas origin")
                test.check(!sprite.idleRunning && sprite.bodyY === 0 && sprite.bodyScale === 1 && sprite.headAngle === 0, "inactive neutral pose")
                test.check(sprite.blinkInterval === 5000, "blink cadence is five seconds")
                sprite.grabToImage(result => {
                    test.check(result.saveToFile(Quickshell.env("NAYORI_SPRITE_OUTPUT") || "/tmp/naomi-sprite.png"), "snapshot")
                    test.captured = true
                })
                test.controller = companion.controller
                companion.active = true
                test.phase = 1
            } else if (test.phase === 1) {
                test.lowestY = Math.min(test.lowestY, sprite.bodyY)
                test.largestScale = Math.max(test.largestScale, sprite.bodyScale)
                test.motionSeen = test.motionSeen || (Math.abs(sprite.headAngle) > 0.5 && Math.abs(sprite.frontAngle) > 0.1)
                test.blinkSeen = test.blinkSeen || sprite.eyesOpen < 0.2
                const motionOutput = Quickshell.env("NAYORI_SPRITE_MOTION_OUTPUT")
                if (motionOutput && !test.motionCaptured && sprite.headAngle > 1.4 && sprite.breath > 0.5) {
                    test.motionCaptured = true
                    sprite.grabToImage(result => test.check(result.saveToFile(motionOutput), "motion snapshot"))
                }
                test.check(sprite.layers[0].angle === 0 && sprite.layers[9].opacity === 1, "stationary legs and neutral mouth")
                if (!test.blinkSeen || sprite.eyesOpen < 0.99) return
                test.check(test.motionSeen && test.lowestY < -2.4 && test.largestScale > 1.009, "subtle idle reaches its intended range")
                sprite.running = false
                test.check(!sprite.idleRunning && sprite.eyesOpen === 1 && sprite.headAngle === 0 && sprite.bodyScale === 1 && sprite.bodyY === 0,
                    "Stop returns a neutral pose and open eyes")
                sprite.running = true
                test.check(sprite.idleRunning, "Start resumes idle")
                theme.animationsEnabled = false
                test.check(!sprite.idleRunning && sprite.bodyY === 0 && sprite.headAngle === 0 && sprite.eyesOpen === 1, "global reduced motion")
                theme.animationsEnabled = true
                companion.say("Привет.", 10)
                companion.companionStyle = "current"
                test.phase = 2
            } else if (test.phase === 2) {
                test.check(companion.controller === test.controller && companion.controller.bubbleText === "Привет.", "style switch preserves controller and reply")
                companion.companionStyle = "pixel-art"
                test.phase = 3
            } else if (test.phase === 3) {
                test.check(companion.illustration.renderer.pixelSize > 0, "pixel art still available")
                companion.companionStyle = "layered"
                test.phase = 4
            } else {
                if (!sprite.ready) return
                companion.active = false
                test.check(!sprite.idleRunning && test.captured, "hidden appearance stops and screenshot completed")
                console.log("NAOMI_SPRITE_PASS ten-layers order idle blink stop start reduced-motion three-styles")
                Qt.quit()
            }
        }
    }
}
