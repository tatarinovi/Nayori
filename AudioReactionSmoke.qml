import QtQuick
import Quickshell
import "services/island"
ShellRoot {
    id: root
    property int beats: 0
    AudioReaction {
        id: audio
        testMode: true; testPlaying: true; testSink: "sink-one"
        testCommand: ["python3", Qt.resolvedUrl("tests/fake-audio.py").toString().replace("file://", "")]
        onBeat: root.beats++
        Component.onCompleted: consumer("test", true)
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    Timer {
        interval: 1000; running: true
        onTriggered: { root.check(audio.available && audio.energy === 0.65 && root.beats > 0, "audio stream"); audio.testSink = "sink-two"; root.check(!audio.available && audio.energy === 0, "output switch clears stale data") }
    }
    Timer {
        interval: 2000; running: true
        onTriggered: { root.check(audio.available && root.beats >= 2, "output reconnect"); audio.testCommand = ["/bin/false"]; audio.restart() }
    }
    Timer {
        interval: 7000; running: true
        onTriggered: { root.check(!audio.available && audio.failures >= 2, "failure backoff"); audio.testPlaying = false }
    }
    Timer {
        interval: 7600; running: true
        onTriggered: { root.check(!audio.process.running && !audio.enabled, "pause stops child"); console.log("AUDIO_REACTION_PASS"); Qt.quit() }
    }
}
