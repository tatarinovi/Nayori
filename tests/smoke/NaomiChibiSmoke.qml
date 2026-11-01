import QtQuick
import Quickshell
import "surfaces/companion"
import "tokens"

ShellRoot {
    id: test
    property int phase: 0
    QtObject {
        id: audio
        property bool playing: true
        property bool available: true
        property bool wanted: false
        signal beat(real strength)
        function consumer(key, value) { wanted = value }
    }
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
            audioReaction: audio
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
                test.check(audio.wanted, "visible chibi requests audio")
                audio.beat(1)
                companion.artworkAlignment = "right"
                test.check(Math.abs(sprite.bubbleAnchor.x - 200) < 0.01, "right alignment includes transparent frame margin")
                companion.artworkAlignment = "left"
                test.check(Math.abs(sprite.bubbleAnchor.x - 89) < 0.01, "left alignment includes transparent frame margin")
                companion.artworkAlignment = "center"
                test.check(Math.abs(sprite.bubbleAnchor.x - 140) < 0.01, "preview remains centered")
            } else if (test.phase === 7) {
                test.check(sprite.closedEyes, "blink timer closes eyes")
                test.check(sprite.headAngle < 0, "head follows the beat")
                audio.beat(1)
            } else if (test.phase === 9) {
                test.check(sprite.headAngle > 0, "successive beats alternate direction")
                audio.playing = false
                test.check(sprite.headAngle === 0, "pause resets the head")
                audio.beat(1)
                test.check(sprite.headAngle === 0, "paused beats ignored")
                audio.playing = true
                audio.available = false
                audio.beat(1)
                test.check(sprite.headAngle === 0, "missing audio ignored")
                audio.available = true
                sprite.pet = 1
                test.check(sprite.running, "active sprite")
            } else if (test.phase === 11) {
                test.check(sprite.ready && !sprite.failed, "pet frame loaded")
                sprite.pet = 0
                sprite.animationsEnabled = false
                test.check(!sprite.running && !sprite.closedEyes && sprite.breathFrame === 0, "motion disabled")
                test.check(!audio.wanted && sprite.headAngle === 0, "reduced motion releases audio and resets head")
            } else if (test.phase === 13) {
                sprite.active = false
                console.log("NAOMI_CHIBI_PASS")
                Qt.quit()
            }
        }
    }
}
