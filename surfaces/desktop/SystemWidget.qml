pragma ComponentBehavior: Bound
import QtQuick
import "WidgetLayout.js" as WidgetLayout

Item {
    id: root
    required property var tokens
    property var reader: null
    property bool large: false
    property var metrics: ["cpu", "memory", "gpu"]

    readonly property string cpuText: {
        if (!reader || reader.cpuFailed)
            return "Процессор недоступен"
        if (reader.cpu === null || reader.cpu === undefined)
            return "Считаем загрузку"
        return WidgetLayout.percentLabel(reader.cpu) || "Процессор недоступен"
    }
    readonly property string memoryText: {
        if (!reader)
            return "Память недоступна"
        if (reader.memoryFailed)
            return "Память недоступна"
        if (reader.memory === null || reader.memory === undefined)
            return "Читаем память"
        return WidgetLayout.percentLabel(reader.memory) || "Память недоступна"
    }
    readonly property string gpuText: reader && reader.gpu !== null && reader.gpu !== undefined
        ? (WidgetLayout.percentLabel(reader.gpu) || "Нет данных") : "Нет данных"
    readonly property bool gpuKnown: gpuText.slice(-1) === "%"
    readonly property bool cpuKnown: cpuText.slice(-1) === "%"
    readonly property bool memoryKnown: memoryText.slice(-1) === "%"

    function fraction(text) {
        if (!text || text.slice(-1) !== "%")
            return 0
        const value = Number(text.slice(0, -1))
        return isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0
    }

    component Meter: Item {
        id: meter
        required property var tokens
        property string title: ""
        property string value: ""
        property real amount: 0
        property bool known: false
        property bool large: false

        DesktopLabel {
            id: caption
            anchors.top: parent.top
            width: parent.width
            tokens: meter.tokens
            text: meter.title
            muted: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
        Canvas {
            id: ring
            anchors.top: caption.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(meter.large ? 68 : 52, parent.width - 8)
            height: width
            antialiasing: true
            property real value: meter.amount
            property color accent: meter.tokens.color.accent
            property color track: Qt.alpha(meter.tokens.color.text, 0.16)
            onValueChanged: requestPaint()
            onAccentChanged: requestPaint()
            onTrackChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const center = width / 2
                const radius = Math.max(1, center - 4)
                ctx.lineWidth = 5
                ctx.lineCap = "round"
                ctx.strokeStyle = track
                ctx.beginPath()
                ctx.arc(center, center, radius, 0, Math.PI * 2)
                ctx.stroke()
                if (meter.known && value > 0) {
                    ctx.strokeStyle = accent
                    ctx.beginPath()
                    ctx.arc(center, center, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value)
                    ctx.stroke()
                }
            }
        }
        DesktopLabel {
            anchors.top: ring.bottom
            anchors.topMargin: 7
            width: parent.width
            tokens: meter.tokens
            text: meter.value
            muted: !meter.known
            font.pixelSize: meter.known ? 13 : 11
            horizontalAlignment: Text.AlignHCenter
            Accessible.name: meter.title + ", " + text
        }
    }

    Row {
        id: meterRow
        anchors.fill: parent
        spacing: 4
        Repeater {
            model: WidgetLayout.normalizeMetrics(root.metrics)
            Meter {
                required property string modelData
                width: (meterRow.width - Math.max(0, WidgetLayout.normalizeMetrics(root.metrics).length - 1) * meterRow.spacing) / WidgetLayout.normalizeMetrics(root.metrics).length
                height: meterRow.height
                tokens: root.tokens
                title: modelData === "cpu" ? "CPU" : modelData === "memory" ? "RAM" : "GPU"
                value: modelData === "cpu" ? (root.cpuKnown ? root.cpuText : "Нет данных") : modelData === "memory" ? (root.memoryKnown ? root.memoryText : "Нет данных") : root.gpuText
                known: modelData === "cpu" ? root.cpuKnown : modelData === "memory" ? root.memoryKnown : root.gpuKnown
                amount: root.fraction(value)
                large: root.large
            }
        }
    }
}
