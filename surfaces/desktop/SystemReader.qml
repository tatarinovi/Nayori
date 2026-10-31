pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "WidgetLayout.js" as WidgetLayout

// Один таймер на слой. Виджеты системы читают эти поля и не открывают /proc сами.
QtObject {
    id: root
    property bool active: false
    property var cpu: null
    property bool cpuFailed: false
    property var memory: null
    property bool memoryFailed: false
    property var previousCpu: null
    property var gpu: null
    property bool gpuFailed: false

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
            return
        }
        memoryFailed = false
        memory = sample.used
    }

    function consumeGpu(contents: string) {
        const match = /^\s*(\d+(?:\.\d+)?)\s*$/.exec(contents)
        const value = match ? Number(match[1]) : NaN
        gpu = isFinite(value) && value >= 0 && value <= 100 ? value / 100 : null
        gpuFailed = gpu === null
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
        memory = null
        memoryFailed = false
        gpu = null
        gpuFailed = false
        if (active) {
            reload()
            reloadGpu()
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
    property FileView mem: FileView {
        path: "/proc/meminfo"
        preload: root.active
        printErrors: false
        onLoaded: root.consumeMemory(text())
        onLoadFailed: {
            root.memoryFailed = true
            root.memory = null
        }
    }
    property Process gpuProcess: Process {
        command: ["sh", "-c", "for f in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do if [ -r \"$f\" ]; then cat \"$f\" && exit 0; fi; done; if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1; fi"]
        stdout: StdioCollector { onStreamFinished: if (root.active) root.consumeGpu(text) }
    }
    property Timer gpuPoll: Timer {
        interval: 3000
        repeat: true
        running: root.active
        onTriggered: root.reloadGpu()
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.reload()
    }
}
