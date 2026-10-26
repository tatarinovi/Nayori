import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "surfaces/companion"

ShellRoot {
    id: test
    Test.TestEvent { id: pointer }
    property int phase: 0
    property var savedController: null
    property int images: 0
    function check(ok, message) {
        if (!ok) { console.error("NAOMI_PIXEL_FAIL " + message); Qt.exit(1) }
    }
    function capture(name) {
        scene.grabToImage(result => {
            test.check(result.saveToFile("/tmp/naomi-pixel-" + name + ".png"), "save " + name)
            test.images++
        })
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 320
        implicitHeight: 560
        color: "#17151d"
        Tokens { id: theme; accentDerived: true; accentSource: "#c0afd1" }
        Item {
            id: scene
            anchors.fill: parent
            NaomiCompanion {
                id: companion
                tokens: theme
                companionStyle: "pixel-art"
                x: 20; y: 16; width: 280; height: 528
                illustrationHeight: companionStyle === "pixel-art" ? 400 : 534
                greet: false
                active: false
            }
        }
    }
    Timer {
        interval: 650
        running: true
        repeat: true
        onTriggered: {
            const art = companion.illustration.renderer
            if (test.phase === 0) {
                test.check(companion.illustrationHeight === 400, "compact pixel height")
                test.check(art && art.eyeOpen === 1, "pixel appearance loaded")
                test.capture("rest")
            } else if (test.phase === 1) {
                theme.accentSource = "#76cbb0"
            } else if (test.phase === 2) {
                test.capture("green")
            } else if (test.phase === 3) {
                test.savedController = companion.controller
                companion.say("Привет.", 10)
                test.check(companion.controller.bubbleVisible, "dialogue on pixel appearance")
                companion.companionStyle = "current"
            } else if (test.phase === 4) {
                test.check(companion.controller === test.savedController, "switch preserves controller")
                test.check(companion.controller.bubbleText === "Привет.", "switch preserves reply")
                companion.companionStyle = "pixel-art"
            } else if (test.phase === 5) {
                companion.controller.hideBubble()
                companion.active = true
                companion.illustration.renderer.tick = 39
                Qt.callLater(() => test.capture("blink"))
            } else if (test.phase === 6) {
                test.check(art.tick !== 0 && art.moving, "8 fps idle clock")
                art.tick = 16
                Qt.callLater(() => test.capture("sway"))
            } else if (test.phase === 7) {
                companion.controller.automatic = false
                const h = companion.headRect
                for (let i = 0; i < 180; i++) {
                    pointer.mouseMove(companion,h.x+h.width/2+0.32*h.width*Math.sin(i*0.45),
                        h.y+h.height*0.45,-1,Qt.NoButton,Qt.NoModifier)
                    companion.controller.advance(1/60)
                }
                test.check(companion.controller.petting && art.pet > 0.5, "pixel head maps to petting controller")
                companion.reactToPointer = false
                companion.controller.advance(0.1)
                test.check(!companion.controller.petting, "pointer toggle disables pixel interaction")
                theme.animationsEnabled = false
                test.check(!art.moving && art.tick === 0 && art.breath === 0 && art.tailAngle === 0 && art.eyeOpen === 1,
                           "reduced motion resets all moving parts")
                companion.active = false
                test.check(!art.moving, "hidden preview stops")
                test.check(test.images === 4, "all preview captures completed")
                console.log("NAOMI_PIXEL_PASS palette switch reply idle blink petting reduced-motion")
                Qt.quit()
            }
            test.phase++
        }
    }
}
