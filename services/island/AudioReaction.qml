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
    property var consumers: ({})
    property int consumerRevision: 0
    readonly property bool wanted: { if (consumerRevision < 0) return false; return Object.keys(consumers).some(k => consumers[k]) }
    readonly property bool playing: testMode ? testPlaying : Mpris.players.values.some(p => p.isPlaying)
    readonly property var sink: testMode ? null : Pw.Pipewire.defaultAudioSink
    readonly property string sinkName: testMode ? testSink : (sink ? sink.name : "")
    readonly property bool enabled: wanted && playing && (testMode || Pw.Pipewire.ready) && sinkName !== ""
    property real energy: 0
    property bool available: false
    property int failures: 0
    property bool intentionalStop: false
    property bool acceptSamples: false
    signal beat(real strength)
    function consumer(key, value) { consumers[key] = value; consumerRevision++ }
    function restart() {
        intentionalStop = intentionalStop || root.process.running
        acceptSamples = false
        root.process.running = false
        root.stale.stop()
        available = false; energy = 0; failures = 0
        root.retry.interval = 500; root.retry.restart()
    }
    onEnabledChanged: restart()
    onSinkNameChanged: restart()
    property Pw.PwObjectTracker tracker: Pw.PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    property Timer retry: Timer {
        interval: 500
        onTriggered: {
            if (root.enabled && !root.process.running) {
                root.process.command = root.testMode ? root.testCommand.concat([root.sinkName]) : ["python3", Quickshell.shellPath("scripts/island-audio.py"), root.sinkName]
                root.process.running = true
            }
        }
    }
    property Timer stale: Timer { interval: 1500; onTriggered: { root.available = false; root.energy = 0 } }
    property Process process: Process {
        onStarted: root.acceptSamples = true
        stdout: SplitParser {
            onRead: data => {
                if (!root.acceptSamples) return
                const values = data.trim().split(/\s+/).map(Number)
                if (values.length !== 2 || !values.every(isFinite)) return
                root.available = true; root.failures = 0
                root.energy = Math.max(0, Math.min(1, values[0])); root.stale.restart()
                if (values[1] > 0) root.beat(Math.min(1, values[1]))
            }
        }
        onExited: {
            root.acceptSamples = false
            root.available = false; root.energy = 0
            if (root.intentionalStop) {
                root.intentionalStop = false
                root.retry.interval = 500; root.retry.restart()
                return
            }
            if (root.enabled && root.failures < 3) { root.failures++; root.retry.interval = 2000 * root.failures; root.retry.restart() }
        }
    }
}
