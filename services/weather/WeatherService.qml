import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool enabled: true
    property string city: ""
    property int refreshMinutes: 15
    property int minuteDurationMs: 60000
    property var requestCommand: []
    property var data: null
    property string error: ""
    readonly property bool loading: request.running
    property double updatedAt: 0
    property bool ready: false
    property int generation: 0
    property int requestGeneration: -1
    property bool pending: false
    property bool exited: false
    property bool collected: false
    property int exitCode: -1
    property string response: ""

    function restartSchedule() {
        schedule.stop()
        if (ready && enabled && city.trim()) schedule.start()
    }

    function refresh() {
        if (!ready || !enabled || !city.trim()) return
        if (request.running || requestGeneration !== -1) return
        requestGeneration = generation
        exited = false
        collected = false
        response = ""
        error = ""
        request.command = requestCommand.length ? requestCommand.concat([city.trim()]) :
            ["curl", "--fail", "--silent", "--show-error", "--max-time", "12",
             "https://wttr.in/" + encodeURIComponent(city.trim()) + "?format=j1"]
        request.running = true
    }

    function finish() {
        if (!exited || !collected || requestGeneration === -1) return
        if (enabled && requestGeneration === generation) {
            if (exitCode !== 0) {
                error = "Погода недоступна. Проверьте соединение и название города"
            } else {
                try {
                    const payload = JSON.parse(response)
                    const current = payload.current_condition && payload.current_condition[0]
                    if (!current || typeof current !== "object" || Array.isArray(current)) throw new Error("condition")
                    for (const field of ["temp_C", "FeelsLikeC", "weatherCode"]) {
                        const value = current[field]
                        if ((typeof value !== "number" && typeof value !== "string") || String(value).trim() === "" || !isFinite(Number(value))) throw new Error(field)
                    }
                    data = current
                    updatedAt = Date.now()
                    error = ""
                } catch (failure) {
                    error = "Не удалось получить погоду. Попробуйте ещё раз"
                }
            }
        }
        requestGeneration = -1
        if (pending) {
            pending = false
            Qt.callLater(root.refresh)
        }
    }

    function locationChanged() {
        generation++
        data = null
        updatedAt = 0
        error = ""
        pending = enabled && city.trim() !== ""
        if (ready && requestGeneration === -1) {
            pending = false
            Qt.callLater(root.refresh)
        }
        restartSchedule()
    }

    onCityChanged: locationChanged()
    onEnabledChanged: {
        generation++
        pending = enabled && city.trim() !== ""
        if (ready && requestGeneration === -1) {
            pending = false
            Qt.callLater(root.refresh)
        }
        restartSchedule()
    }
    onRefreshMinutesChanged: restartSchedule()
    onMinuteDurationMsChanged: restartSchedule()
    Component.onCompleted: {
        ready = true
        pending = false
        restartSchedule()
        refresh()
    }

    property Timer schedule: Timer {
        interval: Math.max(1, Math.round(Math.max(1, Math.min(180, root.refreshMinutes)) * Math.max(1, root.minuteDurationMs)))
        repeat: true
        onTriggered: root.refresh()
    }
    property Process request: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.response = text
                root.collected = true
                root.finish()
            }
        }
        onExited: function(code) {
            root.exitCode = code
            root.exited = true
            root.finish()
        }
    }
}
