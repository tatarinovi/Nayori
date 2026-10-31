pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property var tokens
    required property date now
    property bool large: false

    readonly property var ru: Qt.locale("ru_RU")
    readonly property int timeSize: large ? tokens.type.display.size * 4 : tokens.type.display.size * 2
    readonly property string timeText: ru.toString(now, "HH:mm")
    readonly property string dateText: dateLine(now)

    function dateLine(day) {
        const raw = root.ru.toString(day, "dddd, d MMMM")
        return raw.replace(/(\d+)\s+(\S+)\s*$/, "$1\u00A0$2")
    }

    Column {
        anchors.fill: parent
        spacing: root.large ? 6 : 2
        DesktopLabel {
            width: parent.width
            tokens: root.tokens
            display: true
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
            text: root.dateText
            font.pixelSize: root.large ? root.tokens.type.body.size : root.tokens.type.small.size
            font.family: root.tokens.type.body.family
            font.weight: root.tokens.type.body.weight
        }
    }
}
