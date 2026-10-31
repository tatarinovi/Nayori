pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    required property date now
    property bool large: false
    property string size: large ? "large" : "compact"

    readonly property var ru: Qt.locale("ru_RU")
    readonly property int timeSize: size === "huge" ? 154 : size === "extraLarge" ? 120 : size === "large" ? 90 : 38
    readonly property string timeText: ru.toString(now, "HH:mm")
    readonly property string dateText: dateLine(now)

    function dateLine(day) {
        const raw = root.ru.toString(day, "dddd, d MMMM")
        return raw.replace(/(\d+)\s+(\S+)\s*$/, "$1\u00A0$2")
    }

    Column {
        anchors.fill: parent
        spacing: root.large ? 6 : 0
        DesktopLabel {
            width: parent.width
            tokens: root.tokens
            display: true
            horizontalAlignment: Text.AlignHCenter
            text: root.timeText
            font.pixelSize: root.timeSize
            font.letterSpacing: root.tokens.type.display.letterSpacing * (root.timeSize / Math.max(1, root.tokens.type.display.size))
            lineHeight: 1
            font.features: ({ "tnum": 1 })
            Accessible.name: "Часы, " + text
            Accessible.description: root.dateText
        }
        DesktopLabel {
            width: parent.width
            tokens: root.tokens
            muted: true
            horizontalAlignment: Text.AlignHCenter
            text: root.dateText
            font.pixelSize: root.size === "huge" ? 23 : root.size === "extraLarge" ? 20 : root.large ? 17 : 13
            lineHeight: 1.1
            font.family: root.tokens.type.display.family
            font.weight: root.tokens.type.display.weight
        }
    }
}
