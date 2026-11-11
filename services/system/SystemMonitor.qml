pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../status" as Status

QtObject {
    id: root
    property var consumers: ({})
    property var cpuConsumers: ({})
    property var detailConsumers: ({})
    readonly property bool detailsWanted: revision >= 0 && Object.keys(detailConsumers).length > 0
    onDetailsWantedChanged: if (wanted && worker.running) worker.running = false
    property int revision: 0
    readonly property bool wanted: revision >= 0 && Object.keys(consumers).length > 0
    readonly property bool cpuWanted: wanted || (revision >= 0 && Object.keys(cpuConsumers).length > 0)
    readonly property var cpu: sampler
    readonly property var info: systemInfo
    readonly property var networkStatus: network
    property var data: ({})
    property var histories: ({})
    property bool ready: false
    property string error: ""
    property double lastFrame: 0
    property var testCommand: []
    readonly property bool profileAvailable: ["power-saver", "balanced", "performance"].includes(data.profile)
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    property string profileError: ""
    function chooseProfile(key) {
        if (!profileAvailable || !["power-saver", "balanced", "performance"].includes(key) || (key === "performance" && !hasPerformanceProfile)) return false
        profileError = ""
        try {
            PowerProfiles.profile = key === "power-saver" ? PowerProfile.PowerSaver : key === "performance" ? PowerProfile.Performance : PowerProfile.Balanced
            return true
        } catch (_) {
            profileError = "Не удалось сменить профиль питания"
            return false
        }
    }
    function consumer(key, shown, details = false) {
        if (shown && details) detailConsumers[key] = true
        else delete detailConsumers[key]
        if (shown) consumers[key] = true
        else delete consumers[key]
        revision++
    }
    function cpuConsumer(key, shown) {
        if (shown) cpuConsumers[key] = true
        else delete cpuConsumers[key]
        revision++
    }
    onWantedChanged: {
        data = ({}); histories = ({}); ready = false; error = ""
        retry.stop()
        lastFrame = Date.now()
        if (wanted) worker.running = true
        else worker.running = false
    }
    function consume(line) {
        try {
            const frame = JSON.parse(line)
            if (!frame || typeof frame.time !== "number") throw new Error("snapshot")
            frame.cpu = frame.cpu || ({})
            frame.cpu.load = sampler.valid ? sampler.load * 100 : null
            const values = {cpu: frame.cpu.load}
            for (const row of frame.gpus || []) values["gpu:" + row.id] = row.load
            for (const row of frame.disks || []) values["disk:" + row.id] = row.read === null || row.write === null ? null : row.read + row.write
            for (const row of frame.network || []) values["net:" + row.id] = row.down === null || row.up === null ? null : row.down + row.up
            const next = {}
            for (const key of Object.keys(values)) {
                const points = (histories[key] || []).filter(p => p.t > frame.time - 60)
                points.push({t: frame.time, v: values[key]})
                next[key] = points.slice(-61)
            }
            histories = next; data = frame; ready = true; error = ""; lastFrame = Date.now()
        } catch (_) { fail("Не удалось прочитать показатели") }
    }
    function fail(message) {
        data = ({}); histories = ({}); ready = false; error = message
    }
    property CpuSampler sampler: CpuSampler { active: root.cpuWanted }
    property SystemInfo systemInfo: SystemInfo {}
    property Status.Network network: Status.Network {}
    property Process worker: Process {
        command: root.testCommand.length ? root.testCommand : ["python3", "-u", Qt.resolvedUrl("system_monitor.py").toString().replace(/^file:\/\//, "")].concat(root.detailsWanted ? ["--details"] : [])
        onStarted: root.lastFrame = Date.now()
        stdout: SplitParser { onRead: line => { if (root.wanted) root.consume(line) } }
        onExited: {
            if (root.wanted) {
                root.fail("Сбор показателей прерван. Повторяем подключение…")
                root.retry.restart()
            }
        }
    }
    property Timer retry: Timer { interval: 2500; onTriggered: if (root.wanted) root.worker.running = true }
    property Timer watchdog: Timer {
        interval: 3000; repeat: true; running: root.wanted
        onTriggered: {
            if (Date.now() - root.lastFrame > 5000) {
                root.fail("Показатели не обновляются. Повторяем подключение…")
                root.worker.running = false
            }
        }
    }
}
