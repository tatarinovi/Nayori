import QtQuick
import Quickshell.Io

// Export resolved roles, never recalculate a second palette for the greeter.
QtObject {
    id: root
    required property var tokens
    required property var wallpapers
    property string primaryOutput: ""
    property var outputNames: []
    property bool settled: false
    property string destination: ""
    property string error: ""
    property string lastWritten: ""
    property string inFlight: ""
    readonly property string payload: makePayload()
    function makePayload() {
        if (!tokens || !wallpapers) return ""
        const outputs = {}
        for (const name of outputNames) outputs[name] = wallpapers.wallpaper(name)
        return JSON.stringify({
        colors: {
            background: String(tokens.color.background), surface: String(tokens.color.surface),
            surfaceAlt: String(tokens.color.surfaceAlt), text: String(tokens.color.text),
            textMuted: String(tokens.color.textMuted), accent: String(tokens.color.accent),
            accentText: String(tokens.color.accentText), border: String(tokens.color.border)
        },
        primaryOutput: primaryOutput,
        animationsEnabled: tokens.animationsEnabled,
        enterDuration: tokens.motion.base,
        exitDuration: tokens.motion.fast,
        wallpapers: outputs,
        wallpaper: wallpapers.wallpaper(primaryOutput)
        })
    }
    function schedule() { if (settled && wallpapers && wallpapers.ready && payload !== lastWritten) debounce.restart() }
    function sync() {
        if (!settled || !wallpapers.ready || worker.running || payload === lastWritten) return
        inFlight = payload
        worker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("login_theme.py").toString()).replace(/^file:\/\//, ""), "--json", inFlight]
        if (destination !== "") worker.command = worker.command.concat(["--directory", destination])
        worker.running = true
    }
    onPayloadChanged: schedule()
    onSettledChanged: schedule()
    Component.onCompleted: schedule()
    property Connections wallpaperChanges: Connections {
        target: root.wallpapers
        function onReadyChanged() { root.schedule() }
    }
    property Timer debounceTimer: Timer { id: debounce; interval: 500; onTriggered: root.sync() }
    property Process workerProcess: Process {
        id: worker
        stderr: StdioCollector { id: errors; waitForEnd: true }
        onExited: code => {
            root.error = code === 0 ? "" : "Не удалось сохранить тему экрана входа"
            if (code === 0) root.lastWritten = root.inFlight
            else console.warn(root.error, errors.text)
            if (root.payload !== root.inFlight) root.schedule()
        }
    }
}
