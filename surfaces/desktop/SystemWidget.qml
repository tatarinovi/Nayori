pragma ComponentBehavior: Bound
import QtQuick
import "WidgetLayout.js" as WidgetLayout

Item {
    id: root
    required property var tokens
    property var reader: null
    property bool large: false
    property string size: large ? "large" : "compact"
    property var metrics: ["cpu", "memory", "gpu"]
    readonly property bool detailed: size !== "compact"
    readonly property bool expanded: size === "extraLarge"
    readonly property bool showCpu: WidgetLayout.normalizeMetrics(metrics).indexOf("cpu") >= 0
    readonly property bool showRam: WidgetLayout.normalizeMetrics(metrics).indexOf("memory") >= 0
    readonly property bool showGpu: WidgetLayout.normalizeMetrics(metrics).indexOf("gpu") >= 0 && (!reader || !reader.gpuFailed)
    function percent(value) { return WidgetLayout.percentLabel(value) || "—" }
    function temp(value) { return typeof value === "number" && isFinite(value) ? Math.round(value) + "°C" : "—" }
    function speed(value) {
        if (typeof value !== "number" || !isFinite(value) || value < 0) return "—"
        return value >= 1000000 ? (value / 1000000).toFixed(1) + " MB/s" : (value / 1000).toFixed(0) + " KB/s"
    }
    function memory(used, total) { return WidgetLayout.memoryAmount(used, total) || "—" }

    component Graph: Canvas {
        id: graph
        required property var tokens
        property var samples: []
        property color ink: tokens.color.accent
        property bool shown: root.detailed
        property real scaleMax: 1
        visible: shown
        antialiasing: true
        onSamplesChanged: if (visible) requestPaint()
        onInkChanged: if (visible) requestPaint()
        onScaleMaxChanged: if (visible) requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: if (visible) requestPaint()
        onHeightChanged: if (visible) requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset()
            if (!samples || samples.length < 2) return
            c.lineWidth = 1.5
            const start = Math.max(0, 30 - samples.length)
            let points = []
            function drawSegment() {
                if (points.length < 2) { points = []; return }
                c.beginPath(); c.moveTo(points[0].x, height)
                for (let j = 0; j < points.length; j++) c.lineTo(points[j].x, points[j].y)
                c.lineTo(points[points.length - 1].x, height); c.closePath()
                c.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.28); c.fill()
                c.beginPath(); c.moveTo(points[0].x, points[0].y)
                for (let j = 1; j < points.length; j++) c.lineTo(points[j].x, points[j].y)
                c.strokeStyle = ink; c.stroke(); points = []
            }
            for (let i = 0; i < samples.length; i++) {
                const value = samples[i]
                if (typeof value !== "number" || value < 0 || !isFinite(value)) { drawSegment(); continue }
                points.push({x: (width - 1) * (start + i) / 29,
                             y: (height - 2) * (1 - Math.max(0, Math.min(1, value / Math.max(1, scaleMax)))) + 1})
            }
            drawSegment()
        }
    }
    component Load: Item {
        id: cell
        required property var tokens
        property string title: ""
        property var value: null
        property var temperature: null
        property var history: []
        property color ink: tokens.color.accent
        DesktopLabel { id: caption; anchors.left: parent.left; anchors.top: parent.top; tokens: cell.tokens; display: true; text: cell.title; font.pixelSize: root.expanded ? 20 : 16 }
        DesktopLabel { anchors.right: parent.right; anchors.top: parent.top; width: Math.max(0, parent.width - caption.width - 6); tokens: cell.tokens; horizontalAlignment: Text.AlignRight; text: root.percent(cell.value) + "  |  " + root.temp(cell.temperature); font.pixelSize: root.expanded ? 16 : 13; Accessible.name: cell.title + ", " + text }

        Graph { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: root.expanded ? 62 : 40; tokens: cell.tokens; ink: cell.ink; samples: cell.history }
    }
    component Memory: Item {
        id: meter
        required property var tokens
        property string title: ""
        property var used: null
        property var total: null
        property color ink: tokens.color.accent
        readonly property real ratio: typeof used === "number" && typeof total === "number" && total > 0 ? Math.max(0, Math.min(1, used / total)) : 0
        DesktopLabel { id: memCaption; anchors.left: parent.left; anchors.top: parent.top; tokens: meter.tokens; display: true; text: meter.title; font.pixelSize: root.expanded ? 16 : 13 }
        DesktopLabel { objectName: meter.title === "RAM" ? "desktop-system-detail-memory" : "desktop-system-detail-gpu"; anchors.right: parent.right; anchors.top: parent.top; width: Math.max(0, parent.width - memCaption.width - 4); tokens: meter.tokens; text: root.memory(meter.used, meter.total); horizontalAlignment: Text.AlignRight; font.pixelSize: root.expanded ? 13 : 11; Accessible.name: meter.title + ", " + text }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: root.expanded ? 12 : 9; radius: height / 2; color: Qt.alpha(meter.tokens.color.text, 0.20)
            Rectangle { width: parent.width * meter.ratio; height: parent.height; radius: parent.radius; color: meter.ink }
        }
    }
    Column {
        id: content
        objectName: "desktop-system-meters"
        anchors.fill: parent
        spacing: root.expanded ? 10 : 6
        DesktopLabel { width: parent.width; tokens: root.tokens; display: true; text: "SYSTEM"; font.pixelSize: root.expanded ? 23 : 18 }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.tokens.color.secondary, 0.75) }
        Row {
            width: parent.width; height: root.detailed ? (root.expanded ? 106 : 80) : 25; spacing: 8
            Load { width: root.showGpu && root.showCpu ? (parent.width - 2 * parent.spacing - 1) / 2 : parent.width; height: parent.height; visible: root.showCpu; tokens: root.tokens; title: "CPU"; value: root.reader ? root.reader.cpu : null; temperature: root.reader ? root.reader.cpuTemp : null; history: root.reader && root.reader.cpuHistory ? root.reader.cpuHistory : [] }
            Rectangle { width: 1; height: parent.height; visible: root.showCpu && root.showGpu; color: Qt.alpha(root.tokens.color.secondary, 0.65) }
            Load { objectName: "desktop-system-gpu"; width: root.showGpu && root.showCpu ? (parent.width - 2 * parent.spacing - 1) / 2 : parent.width; height: parent.height; visible: root.showGpu; tokens: root.tokens; title: "GPU"; value: root.reader ? root.reader.gpu : null; temperature: root.reader ? root.reader.gpuTemp : null; history: root.reader && root.reader.gpuHistory ? root.reader.gpuHistory : []; ink: root.tokens.color.secondary }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.tokens.color.border, 0.7) }
        Row {
            width: parent.width; height: root.expanded ? 48 : 40; spacing: 8
            Memory { width: root.showRam && root.showGpu ? (parent.width - 2 * parent.spacing - 1) / 2 : parent.width; height: parent.height; visible: root.showRam; tokens: root.tokens; title: "RAM"; used: root.reader ? root.reader.memoryUsedKb : null; total: root.reader ? root.reader.memoryTotalKb : null }
            Rectangle { width: 1; height: parent.height; visible: root.showRam && root.showGpu; color: Qt.alpha(root.tokens.color.secondary, 0.65) }
            Memory { width: root.showRam && root.showGpu ? (parent.width - 2 * parent.spacing - 1) / 2 : parent.width; height: parent.height; visible: root.showGpu; tokens: root.tokens; title: "VRAM"; used: root.reader ? root.reader.gpuMemoryUsedKb : null; total: root.reader ? root.reader.gpuMemoryTotalKb : null; ink: root.tokens.color.secondary }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.tokens.color.secondary, 0.75) }
        Row {
            width: parent.width; height: root.detailed ? (root.expanded ? 108 : 94) : 48; spacing: 8
            Column {
                width: root.detailed ? (parent.width - 2 * parent.spacing - 1) / 2 : parent.width; spacing: 4
                DesktopLabel { width: parent.width; visible: root.detailed; tokens: root.tokens; display: true; text: "Network"; font.pixelSize: root.expanded ? 16 : 13 }
                Row {
                    width: parent.width; spacing: 3
                    DesktopLabel { tokens: root.tokens; color: root.tokens.color.accent; text: "↓"; font.pixelSize: root.expanded ? 18 : 14 }
                    DesktopLabel { tokens: root.tokens; text: root.speed(root.reader ? root.reader.networkRx : null); font.pixelSize: root.expanded ? 13 : 11; Accessible.name: "Download " + text }
                    DesktopLabel { tokens: root.tokens; color: root.tokens.color.secondary; text: "↑"; font.pixelSize: root.expanded ? 18 : 14 }
                    DesktopLabel { tokens: root.tokens; text: root.speed(root.reader ? root.reader.networkTx : null); font.pixelSize: root.expanded ? 13 : 11; Accessible.name: "Upload " + text }
                }
                Item {
                    id: networkGraph
                    objectName: "desktop-network-graph"
                    width: parent.width; height: root.expanded ? 42 : root.detailed ? 30 : 18
                    readonly property var rx: root.reader && root.reader.networkRxHistory ? root.reader.networkRxHistory : []
                    readonly property var tx: root.reader && root.reader.networkTxHistory ? root.reader.networkTxHistory : []
                    readonly property real peak: {
                        let max = 1
                        for (const v of rx.concat(tx)) if (typeof v === "number" && isFinite(v) && v > max) max = v
                        return max
                    }
                    Accessible.name: "Network history: download and upload"
                    Graph { anchors.fill: parent; tokens: root.tokens; shown: true; scaleMax: networkGraph.peak; samples: networkGraph.rx }
                    Graph { anchors.fill: parent; tokens: root.tokens; shown: true; scaleMax: networkGraph.peak; samples: networkGraph.tx; ink: root.tokens.color.secondary }
                }
            }
            Rectangle { width: 1; height: parent.height; visible: root.detailed; color: Qt.alpha(root.tokens.color.secondary, 0.65) }
            Column {
                width: (parent.width - 2 * parent.spacing - 1) / 2; visible: root.detailed; spacing: 2
                DesktopLabel { width: parent.width; tokens: root.tokens; display: true; text: "Processes"; font.pixelSize: root.expanded ? 16 : 13 }
                Repeater { model: root.reader && root.reader.topProcesses && root.reader.topProcesses.length ? root.reader.topProcesses : []
                    delegate: Item {
                        id: processRow
                        required property var modelData
                        required property int index
                        objectName: "desktop-system-process-" + index
                        width: parent.width; height: root.expanded ? 20 : 18
                        DesktopLabel { anchors.left: parent.left; anchors.right: processValue.left; tokens: root.tokens; text: String(processRow.modelData.name || ""); font.pixelSize: root.expanded ? 13 : 12; Accessible.name: text + (processValue.visible ? ", " + processValue.text : "") }
                        DesktopLabel { id: processValue; anchors.right: parent.right; width: visible ? 46 : 0; tokens: root.tokens; visible: root.expanded && typeof processRow.modelData.cpu === "number"; horizontalAlignment: Text.AlignRight; text: visible ? processRow.modelData.cpu.toFixed(1) + "%" : ""; font.pixelSize: 13 }
                    }
                }
                DesktopLabel { width: parent.width; visible: !root.reader || !root.reader.topProcesses || root.reader.topProcesses.length === 0; tokens: root.tokens; muted: true; text: "—"; font.pixelSize: 11 }
            }
        }
    }
}
