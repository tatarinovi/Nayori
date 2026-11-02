pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "WidgetLayout.js" as WidgetLayout

// Один таймер на слой. Виджеты системы читают эти поля и не открывают /proc сами.
QtObject {
    id: root
    property bool active: false
    property bool showDetails: false
    property var cpuTemp: null
    property var gpuTemp: null
    property var networkRx: null
    property var networkTx: null
    property var networkPrevious: null
    property var networkRxHistory: []
    property var networkTxHistory: []
    property var topProcesses: []
    property var cpuHistory: []
    property var gpuHistory: []
    function consumeExtra(text: string) {
        let data
        try { data = JSON.parse(text) } catch (e) { data = null }
        if (!data) { cpuTemp = null; networkPrevious = null; networkRx = null; networkTx = null; topProcesses = []; recordNetwork(); return }
        cpuTemp = typeof data.cpuTemp === "number" && isFinite(data.cpuTemp) ? data.cpuTemp : null
        const now = Date.now()
        if (typeof data.rx === "number" && typeof data.tx === "number" && data.rx >= 0 && data.tx >= 0) {
            if (networkPrevious && now > networkPrevious.at && data.rx >= networkPrevious.rx && data.tx >= networkPrevious.tx) {
                const seconds = (now - networkPrevious.at) / 1000
                networkRx = (data.rx - networkPrevious.rx) / seconds
                networkTx = (data.tx - networkPrevious.tx) / seconds
            } else { networkRx = null; networkTx = null }
            networkPrevious = { rx: data.rx, tx: data.tx, at: now }
        } else { networkPrevious = null; networkRx = null; networkTx = null }
        recordNetwork()
        topProcesses = showDetails && Array.isArray(data.processes) ? data.processes.slice(0, 3) : []
    }
    function recordNetwork() {
        networkRxHistory = networkRxHistory.concat([typeof networkRx === "number" && isFinite(networkRx) ? networkRx : -1]).slice(-30)
        networkTxHistory = networkTxHistory.concat([typeof networkTx === "number" && isFinite(networkTx) ? networkTx : -1]).slice(-30)
    }
    property var cpu: null
    property bool cpuFailed: false
    property var cpuInfo: null
    property var memory: null
    property bool memoryFailed: false
    property var memoryTotalKb: null
    property var memoryUsedKb: null
    property var previousCpu: null
    property var gpu: null
    property bool gpuFailed: false
    property var gpuMemoryUsedKb: null
    property var gpuMemoryTotalKb: null

    function resetCpu() {
        previousCpu = null
        cpu = null
    }

    function consumeCpu(contents: string) {
        const sample = WidgetLayout.readCpuCounters(contents)
        if (!sample) {
            cpuFailed = true
            resetCpu()
            return
        }
        const load = WidgetLayout.cpuLoad(previousCpu, sample)
        previousCpu = sample
        cpuFailed = false
        cpu = load
    }

    function consumeMemory(contents: string) {
        const sample = WidgetLayout.readMeminfo(contents)
        if (!sample) {
            memoryFailed = true
            memory = null
            memoryTotalKb = null
            memoryUsedKb = null
            return
        }
        memoryFailed = false
        memory = sample.used
        memoryTotalKb = sample.totalKb
        memoryUsedKb = sample.totalKb - sample.availableKb
    }

    function consumeGpu(contents: string) {
        const lines = contents.trim().split("\n")
        let usage = NaN
        let used = NaN
        let total = NaN
        if (lines[0] === "AMD") {
            usage = lines[1] && lines[1].trim() !== "" ? Number(lines[1]) : NaN
            used = lines[2] ? Number(lines[2]) / 1024 : NaN
            total = lines[3] ? Number(lines[3]) / 1024 : NaN
        } else if (lines[0] === "NVIDIA") {
            const fields = (lines[1] || "").split(",")
            usage = fields[0] && fields[0].trim() !== "" ? Number(fields[0]) : NaN
            used = fields[1] && fields[1].trim() !== "" ? Number(fields[1]) * 1024 : NaN
            total = fields[2] && fields[2].trim() !== "" ? Number(fields[2]) * 1024 : NaN
        } else {
            const match = /^\s*(\d+(?:\.\d+)?)\s*$/.exec(contents)
            usage = match ? Number(match[1]) : NaN
        }
        gpu = isFinite(usage) && usage >= 0 && usage <= 100 ? usage / 100 : null
        gpuFailed = gpu === null
        const rawTemp = lines[0] === "NVIDIA" ? (lines[1] || "").split(",")[3] : lines[0] === "AMD" ? lines[4] : ""
        const temp = rawTemp && String(rawTemp).trim() ? Number(rawTemp) / (lines[0] === "AMD" ? 1000 : 1) : NaN
        gpuTemp = isFinite(temp) && temp > 0 && temp <= 150 ? temp : null
        const validMemory = isFinite(used) && isFinite(total) && total > 0 && used >= 0 && used <= total
        gpuMemoryUsedKb = validMemory ? used : null
        gpuMemoryTotalKb = validMemory ? total : null
    }

    function reloadGpu() {
        if (active && !gpuProcess.running)
            gpuProcess.running = true
    }

    function reload() {
        if (!active)
            return
        stat.reload()
        mem.reload()
    }

    onActiveChanged: {
        resetCpu()
        cpuFailed = false
        cpuInfo = null
        memory = null
        memoryTotalKb = null
        memoryUsedKb = null
        memoryFailed = false
        gpuMemoryUsedKb = null
        gpuMemoryTotalKb = null
        gpu = null
        gpuTemp = null; cpuTemp = null; networkPrevious = null
        networkRx = null; networkTx = null; networkRxHistory = []; networkTxHistory = []; topProcesses = []; cpuHistory = []; gpuHistory = []
        gpuFailed = false
        if (active) {
            reload()
            reloadGpu()
            reloadExtra()
        }
    }

    property FileView stat: FileView {
        path: "/proc/stat"
        preload: root.active
        printErrors: false
        onLoaded: root.consumeCpu(text())
        onLoadFailed: {
            root.cpuFailed = true
            root.resetCpu()
        }
    }
    property FileView cpuInfoFile: FileView {
        path: "/proc/cpuinfo"
        preload: root.active
        printErrors: false
        onLoaded: root.cpuInfo = WidgetLayout.readCpuInfo(text())
        onLoadFailed: root.cpuInfo = null
    }
    property FileView mem: FileView {
        path: "/proc/meminfo"
        preload: root.active
        printErrors: false
        onLoaded: root.consumeMemory(text())
        onLoadFailed: {
            root.memoryFailed = true
            root.memory = null
            root.memoryTotalKb = null
            root.memoryUsedKb = null
        }
    }
    property Process gpuProcess: Process {
        command: ["sh", "-c", "for f in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do if [ -r \"$f\" ]; then d=${f%/*}; printf \"AMD\\n\"; cat \"$f\"; cat \"$d/mem_info_vram_used\" 2>/dev/null || printf \"\\n\"; cat \"$d/mem_info_vram_total\" 2>/dev/null || printf \"\\n\"; for t in \"$d\"/hwmon/hwmon*/temp1_input; do if [ -r \"$t\" ]; then cat \"$t\"; break; fi; done; exit 0; fi; done; if command -v nvidia-smi >/dev/null 2>&1; then printf \"NVIDIA\\n\"; nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1; fi"]
        stdout: StdioCollector { onStreamFinished: if (root.active) root.consumeGpu(text) }
    }
    function reloadExtra() {
        if (active && !extraProcess.running) {
            extraProcess.command = ["python3", Quickshell.shellPath("scripts/desktop-system-extra.py"), showDetails ? "details" : "compact"]
            extraProcess.running = true
        }
    }
    property Process extraProcess: Process {
        stdout: StdioCollector { onStreamFinished: if (root.active) root.consumeExtra(text) }
    }
    property Timer detailsPoll: Timer {
        interval: 2000; repeat: true; running: root.active
        onTriggered: {
            root.reloadExtra()
            if (root.showDetails) {
                root.cpuHistory = root.cpuHistory.concat([root.cpu === null ? -1 : root.cpu]).slice(-30)
                root.gpuHistory = root.gpuHistory.concat([root.gpu === null ? -1 : root.gpu]).slice(-30)
            }
        }
    }
    property Timer gpuPoll: Timer {
        interval: 3000
        repeat: true
        running: root.active
        onTriggered: { root.reloadGpu(); root.cpuInfoFile.reload() }
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.reload()
    }
}
