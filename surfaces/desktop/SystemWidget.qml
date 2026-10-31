pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower
import "WidgetLayout.js" as WidgetLayout

Item {
    id: root
    required property var tokens
    property var reader: null
    property bool large: false

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryReady: battery && battery.ready && battery.isPresent
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
    readonly property string batteryPercentText: batteryReady ? WidgetLayout.batteryPercent(battery.percentage) : ""
    readonly property string batteryText: {
        if (!battery || !battery.ready)
            return "Сведения о\u00A0питании недоступны"
        if (!battery.isPresent)
            return "Батареи нет"
        return batteryPercentText || "Заряд неизвестен"
    }
    readonly property string batteryDetail: batteryPercentText !== "" ? (UPower.onBattery ? "От батареи" : "От сети") : ""
    readonly property bool cpuKnown: cpuText.slice(-1) === "%"
    readonly property bool memoryKnown: memoryText.slice(-1) === "%"

    function fraction(text) {
        if (!text || text.slice(-1) !== "%")
            return 0
        const value = Number(text.slice(0, -1))
        return isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0
    }

    Column {
        anchors.fill: parent
        spacing: root.large ? 10 : 8
        Column {
            width: parent.width
            spacing: 4
            Row {
                width: parent.width
                spacing: 8
                DesktopLabel {
                    width: Math.max(0, parent.width - cpuValue.width - parent.spacing)
                    tokens: root.tokens
                    text: "Процессор"
                }
                DesktopLabel {
                    id: cpuValue
                    tokens: root.tokens
                    muted: !root.cpuKnown
                    text: root.cpuText
                    Accessible.name: "Процессор, " + text
                }
            }
            Rectangle {
                width: parent.width
                height: 3
                radius: 1.5
                visible: root.cpuKnown
                color: Qt.alpha(root.tokens.color.text, 0.14)
                Rectangle {
                    width: parent.width * root.fraction(root.cpuText)
                    height: parent.height
                    radius: parent.radius
                    color: root.tokens.color.accent
                }
            }
        }
        Column {
            width: parent.width
            spacing: 4
            Row {
                width: parent.width
                spacing: 8
                DesktopLabel {
                    width: Math.max(0, parent.width - memoryValue.width - parent.spacing)
                    tokens: root.tokens
                    text: "Память"
                }
                DesktopLabel {
                    id: memoryValue
                    tokens: root.tokens
                    muted: !root.memoryKnown
                    text: root.memoryText
                    Accessible.name: "Память, " + text
                }
            }
            Rectangle {
                width: parent.width
                height: 3
                radius: 1.5
                visible: root.memoryKnown
                color: Qt.alpha(root.tokens.color.text, 0.14)
                Rectangle {
                    width: parent.width * root.fraction(root.memoryText)
                    height: parent.height
                    radius: parent.radius
                    color: root.tokens.color.accent
                }
            }
        }
        Column {
            width: parent.width
            spacing: 2
            Row {
                width: parent.width
                spacing: 8
                DesktopLabel {
                    width: Math.max(0, parent.width - batteryValue.width - parent.spacing)
                    tokens: root.tokens
                    text: "Батарея"
                }
                DesktopLabel {
                    id: batteryValue
                    width: Math.min(implicitWidth, parent.width * 0.72)
                    horizontalAlignment: Text.AlignRight
                    tokens: root.tokens
                    muted: root.batteryPercentText === ""
                    text: root.batteryText
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    Accessible.name: "Батарея, " + text
                }
            }
            DesktopLabel {
                width: parent.width
                visible: root.batteryDetail !== ""
                tokens: root.tokens
                muted: true
                text: root.batteryDetail
                font.pixelSize: root.tokens.type.small.size
            }
            Rectangle {
                width: parent.width
                height: 3
                radius: 1.5
                visible: root.batteryPercentText !== ""
                color: Qt.alpha(root.tokens.color.text, 0.14)
                Rectangle {
                    width: parent.width * root.fraction(root.batteryPercentText)
                    height: parent.height
                    radius: parent.radius
                    color: root.tokens.color.accent
                }
            }
        }
    }
}
