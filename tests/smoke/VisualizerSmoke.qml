pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens"
import "services/settings"
import "services/visualizer"
import "surfaces/visualizer"
import "surfaces/visualizer/vendor"
import "services/visualizer/VisualizerConfig.js" as Config

ShellRoot {
    id: test
    property int phase: 0
    property int attempts: 0
    property string firstId: ""
    property string auraId: ""
    Tokens { id: theme }
    SettingsService { id: store; storageDirectory: Quickshell.env("NAYORI_VISUALIZER_TEST_DIR") }
    VisualizerService { id: service; settings: store }
    QtObject {
        id: audio
        property bool available: true
        property real energy: 0.5
        property real volume: 0.12
        property var spectrum: Array.from({length:48}, (_,i) => 0.4 + Math.sin(i) * 0.2)
        property var visualizerSpectrum: Array.from({length:128}, (_,i) => 0.4 + Math.sin(i) * 0.2)
        property var waveform: Array.from({length:128}, (_,i) => Math.sin(i * 0.4) * 0.1)
        property var consumers: ({})
        function systemConsumer(key, value) { if (value) consumers[key] = true; else delete consumers[key] }
    }
    VizItem { id: cfg; data: service.items.find(v=>v.id===test.firstId) || {} }
    Motion { id: motion; cfg: cfg; sourceAudio: audio }
    AuraMotion { id: auraMotion; cfg: cfg; sourceAudio: audio }
    FloatingWindow {
        visible: true
        implicitWidth: 1080; implicitHeight: 720
        color: theme.color.background
        Item {
            width: 720; height: 720
            VisualizerLayer { id: layer; anchors.fill: parent; service: service; tokens: theme; output: "DP-1"; sourceAudio: audio; editing: true }
        }
        VisualizerPane { id: pane; x: 732; width: 336; height: 700; tokens: theme; service: service; output: "DP-1"; sourceAudio: audio }
    }
    function check(ok, message) {
        if (!ok) { console.error("VISUALIZER_FAIL " + message); Qt.exit(1) }
    }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            test.attempts++
            test.check(test.attempts < 100, "timeout")
            if (!store.ready) return
            if (Quickshell.env("NAYORI_VISUALIZER_RESTORE") === "1") {
                test.check(service.items.length === 13, "no restart duplicates")
                test.check(service.items[0].style === "curtain" && service.items[0].angle === 38, "placement and style restored")
                test.check(service.items[0].color === "#125678", "manual colour restored")
                test.check(service.items.some(v=>v.style==="aura"&&v.auraDepth===270), "field restored")
                test.check(service.onOutput("DP-2").length === 1, "disconnected monitor kept")
                console.log("VISUALIZER_RESTORE_PASS"); Qt.quit(); return
            }
            if (test.phase === 0) {
                test.firstId = service.add("DP-1")
                service.patch(test.firstId, {style:"curtain",angle:38,w:0.7,h:0.3,x:0.1,y:0.2,color:"#125678"})
                for (const style of Config.choices.style.filter(style => style !== "curtain")) {
                    const id = service.add(style === "orb" ? "DP-2" : "DP-1")
                    service.patch(id, {style:style})
                    if (style === "aura") { test.auraId = id; service.patch(id,{auraDepth:270}) }
                }
                service.select(test.firstId)
                test.check(service.items.length === 13 && layer.instances.length === 12, "independent instances")
            } else if (test.phase === 1) {
                test.check(motion.levels.length === 64 && motion.energy > 0, "spectrum responds")
                test.check(auraMotion.bands.length === 12 && auraMotion.energy > 0, "aura responds")
                pane.tab = "Place"
                service.patch(test.firstId, {gain:1.7})
                test.check(service.items.find(v=>v.id===test.auraId).gain === 1, "independent parameters")
            } else if (test.phase === 2) pane.tab = "Colour"
            else if (test.phase === 3) pane.tab = "Motion"
            else if (test.phase === 4) pane.tab = "Shape"
            else if (test.phase === 5) { service.select(test.auraId); pane.tab = "Field" }
            else if (test.phase === 6) {
                test.check(pane.parameterModel.length === 33, "all field controls")
                const before = Object.keys(audio.consumers).length
                service.patch(test.firstId,{enabled:false})
                test.check(layer.instances.length === 11 && before === 1, "one subscription per layer")
                service.patch(test.firstId,{enabled:true})
                const id = service.add("DP-1"); service.remove(id)
                test.check(service.items.length === 13, "deletion")
                audio.available = false; audio.energy = 0; audio.spectrum = []; audio.visualizerSpectrum = []; audio.waveform = []
            } else if (test.phase === 7) {
                theme.animationsEnabled = false
            } else if (test.phase === 8) {
                test.check(Object.keys(audio.consumers).length === 0, "motion off unsubscribes")
                theme.animationsEnabled = true
                store.flush(false)
            } else if (test.phase === 10) {
                if (store.dirty || store.saving) return
                console.log("VISUALIZER_SMOKE_PASS"); Qt.quit()
            }
            test.phase++
        }
    }
}
