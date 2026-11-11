import QtQuick
import Quickshell
import "services/island"

ShellRoot {
    id: test
    property int phase: 0
    AudioReaction {
        id: audio
        testMode: true
        testPlaying: false
        testSink: "fixture-first"
        testCommand: ["python3", Quickshell.shellPath("fake-visualizer-audio.py")]
        Component.onCompleted: { systemConsumer("first", true); systemConsumer("second", true) }
    }
    function check(ok, message) {
        if (!ok) { console.error("VISUALIZER_AUDIO_FAIL " + message); Qt.exit(1) }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            if (test.phase === 0) {
                test.check(audio.available && audio.enabled && !audio.playing, "capture without MPRIS")
                test.check(audio.spectrum.length === 48 && audio.visualizerSpectrum.length === 128 && audio.waveform.length === 128, "shared FFT and waveform protocol")
                audio.systemConsumer("first", false)
                test.check(audio.enabled && audio.process.running, "second instance retains shared worker")
                audio.testSink = "fixture-second"
                test.check(!audio.available && audio.waveform.length === 0, "sink switch discards stale samples")
            } else if (test.phase === 1) {
                test.check(audio.available, "reconnect to new output")
                audio.testCommand = ["/bin/false"]; audio.restart()
            } else if (test.phase === 2) {
                test.check(!audio.available && audio.failures >= 1, "failed worker clears source")
                audio.testCommand = ["python3", Quickshell.shellPath("fake-visualizer-audio.py")]
                audio.restart()
            } else if (test.phase === 3) {
                test.check(audio.available, "recover after backend returns")
                audio.systemConsumer("second", false)
                test.check(!audio.enabled, "last subscriber stops capture")
            } else if (test.phase === 4) {
                test.check(!audio.process.running && Object.keys(audio.systemConsumers).length === 0, "worker released")
                console.log("VISUALIZER_AUDIO_PASS"); Qt.quit()
            }
            test.phase++
        }
    }
}
