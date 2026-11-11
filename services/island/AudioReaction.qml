import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire as Pw
QtObject {
    id: root
    property bool testMode: false
    property bool testPlaying: false
    property string testSink: ""
    property var testCommand: []
    property int requestedFps: 30
    readonly property int captureFps: systemWanted && [30,45,60].includes(requestedFps) ? requestedFps : 30
    onCaptureFpsChanged: restart()
    property var consumers: ({})
    property int consumerRevision: 0
    property var systemConsumers: ({})
    property int systemRevision: 0
    readonly property bool systemWanted: { if (systemRevision < 0) return false; return Object.keys(systemConsumers).some(k => systemConsumers[k]) }
    readonly property bool wanted: { if (consumerRevision < 0) return false; return Object.keys(consumers).some(k => consumers[k]) }
    readonly property bool playing: testMode ? testPlaying : Mpris.players.values.some(p => p.isPlaying)
    readonly property var sink: testMode ? null : Pw.Pipewire.defaultAudioSink
    readonly property string sinkName: testMode ? testSink : (sink ? sink.name : "")
    readonly property bool enabled: ((wanted && playing) || systemWanted) && (testMode || Pw.Pipewire.ready) && sinkName !== ""
    property real energy: 0
    // Cava's 48 frequency bands, ordered from bass to treble. Empty when unavailable.
    property var spectrum: []
    property var visualizerSpectrum: []
    property var waveform: []
    property real volume: 0
    property real volumeReference: 0
    property double volumeSampleAt: 0
    function updateVolume(sample) {
        const now = Date.now()
        const elapsed = volumeSampleAt ? Math.max(0, Math.min(1, (now - volumeSampleAt) / 1000)) : 1 / 30
        volumeSampleAt = now
        volume = sample
        // A slow broadband reference preserves local loudness changes at any output level.
        volumeReference = volumeReference > 0 ? volumeReference + (sample - volumeReference) * (1 - Math.exp(-elapsed / 2.5)) : sample
    }
    function clearVolume() { volume = 0; volumeReference = 0; volumeSampleAt = 0 }
    property bool available: false
    property int failures: 0
    property bool intentionalStop: false
    property bool acceptSamples: false
    signal beat(real strength)
    function consumer(key, value) { if (value) consumers[key] = true; else delete consumers[key]; consumerRevision++ }
    function systemConsumer(key, value) { if (value) systemConsumers[key] = true; else delete systemConsumers[key]; systemRevision++ }
    function restart() {
        intentionalStop = intentionalStop || root.process.running
        acceptSamples = false
        root.process.running = false
        root.stale.stop()
        available = false; energy = 0; spectrum = []; visualizerSpectrum = []; waveform = []; clearVolume(); failures = 0
        root.retry.interval = 500; root.retry.restart()
    }
    onEnabledChanged: restart()
    onSinkNameChanged: restart()
    property Pw.PwObjectTracker tracker: Pw.PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    property Timer retry: Timer {
        interval: 500
        onTriggered: {
            if (root.enabled && !root.process.running) {
                root.process.command = root.testMode ? root.testCommand.concat([root.sinkName]) : ["python3", Quickshell.shellPath("scripts/island-audio.py"), root.sinkName, String(root.captureFps)]
                root.process.running = true
            }
        }
    }
    property Timer stale: Timer { interval: 1500; onTriggered: { root.available = false; root.energy = 0; root.spectrum = []; root.visualizerSpectrum = []; root.waveform = []; root.clearVolume(); if (root.systemWanted && root.enabled) root.restart() } }
    property Process process: Process {
        onStarted: { root.acceptSamples = true; root.stale.restart() }
        stdout: SplitParser {
            onRead: data => {
                if (!root.acceptSamples) return
                const values = data.trim().split(/\s+/).map(Number)
                if (![2, 3, 51, 307].includes(values.length) || !values.every(isFinite)) return
                root.available = true; root.failures = 0
                root.updateVolume(values.length >= 3 ? Math.max(0, Math.min(1, values[2])) : 0)
                root.spectrum = values.length >= 51 ? values.slice(3, 51).map(v => Math.max(0, Math.min(1, v))) : []
                root.visualizerSpectrum = values.length === 307 ? values.slice(51, 179).map(v => Math.max(0, Math.min(1, v))) : root.spectrum
                root.waveform = values.length === 307 ? values.slice(179).map(v => Math.max(-1, Math.min(1, v))) : []
                root.energy = Math.max(0, Math.min(1, values[0])); root.stale.restart()
                if (values[1] > 0) root.beat(Math.min(1, values[1]))
            }
        }
        onExited: {
            root.stale.stop()
            root.acceptSamples = false
            root.available = false; root.energy = 0; root.spectrum = []; root.visualizerSpectrum = []; root.waveform = []; root.clearVolume()
            if (root.intentionalStop) {
                root.intentionalStop = false
                root.retry.interval = 500; root.retry.restart()
                return
            }
            if (root.enabled && (root.systemWanted || root.failures < 3)) { root.failures = Math.min(15, root.failures + 1); root.retry.interval = Math.min(30000, 2000 * root.failures); root.retry.restart() }
        }
    }
}
