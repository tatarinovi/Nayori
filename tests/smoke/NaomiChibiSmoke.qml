import QtQuick
import Quickshell
import "surfaces/companion"
import "tokens"

ShellRoot {
    id: test
    property int phase: 0
    function check(ok, message) {
        if (!ok) { console.error("NAOMI_CHIBI_FAIL " + message); Qt.exit(1) }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 280; implicitHeight: 328
        color: "transparent"
        Tokens { id: theme }
        NaomiCompanion {
            id: companion
            anchors.fill: parent
            tokens: theme
            companionStyle: "chibi"
            illustrationHeight: 200
            greet: false
        }
    }
    Timer {
        interval: 80; running: true; repeat: true
        onTriggered: {
            test.phase++
            const sprite = companion.illustration.renderer
            if (test.phase === 2) {
                test.check(sprite && sprite.ready && !sprite.failed, "idle frame loaded")
                sprite.blinkInterval = 300
                companion.grabToImage(result => result.saveToFile("/tmp/nayori-chibi-smoke.png"))
                test.check(sprite.headRect.width > 0 && sprite.bubbleAnchor.y > 0, "interaction geometry")
                companion.artworkAlignment = "right"
                test.check(Math.abs(sprite.bubbleAnchor.x - 200) < 0.01, "right alignment includes transparent frame margin")
                companion.artworkAlignment = "left"
                test.check(Math.abs(sprite.bubbleAnchor.x - 89) < 0.01, "left alignment includes transparent frame margin")
                companion.artworkAlignment = "center"
                test.check(Math.abs(sprite.bubbleAnchor.x - 140) < 0.01, "preview remains centered")
            } else if (test.phase === 7) {
                test.check(sprite.closedEyes, "blink timer closes eyes")
            } else if (test.phase === 9) {
                sprite.pet = 1
                test.check(sprite.running, "active sprite")
            } else if (test.phase === 11) {
                test.check(sprite.ready && !sprite.failed, "pet frame loaded")
                sprite.pet = 0
                sprite.animationsEnabled = false
                test.check(!sprite.running && !sprite.closedEyes && sprite.breathFrame === 0, "motion disabled")
            } else if (test.phase === 13) {
                sprite.active = false
                console.log("NAOMI_CHIBI_PASS")
                Qt.quit()
            }
        }
    }
}
