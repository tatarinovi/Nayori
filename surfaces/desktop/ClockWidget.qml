pragma ComponentBehavior: Bound
import QtQuick
import "../../tokens/AccentRoles.js" as AccentRoles

Item {
    id: root
    required property var tokens
    required property date now
    property var wallpaperAccent: null
    property bool card: true
    property bool editing: false
    property bool large: false
    property string size: large ? "large" : "compact"

    readonly property var ru: Qt.locale("ru_RU")
    readonly property int timeSize: size === "huge" ? 245 : size === "extraLarge" ? 195 : size === "large" ? 145 : 48
    readonly property int dateWidth: size === "huge" ? 148 : size === "extraLarge" ? 122 : 100
    readonly property bool clockFontReady: clockFont.status === FontLoader.Ready
    // Cardless clocks need light ink and a dark outline even in the light theme:
    // the actual wallpaper is independent of the shell's surface palette.
    readonly property color outlineColor: tokens.light ? tokens.color.text : tokens.color.background
    readonly property color clockAccent: AccentRoles.accentOnSurface(
        wallpaperAccent || (card ? tokens.color.accent : tokens.accentSource),
        card ? tokens.color.background : outlineColor)
    readonly property string timeText: ru.toString(now, "HH:mm")
    readonly property string dateText: dateLine(now)
    readonly property string dayText: ru.toString(now, "d")
    readonly property string monthText: ru.toString(now, "d MMMM").replace(/^\d+\s+/, "").toUpperCase()
    readonly property string weekdayText: ru.toString(now, "dddd").toUpperCase()

    function dateLine(day) {
        const raw = root.ru.toString(day, "dddd, d MMMM")
        return raw.replace(/(\d+)\s+(\S+)\s*$/, "$1\u00A0$2")
    }

    FontLoader {
        id: clockFont
        source: Qt.resolvedUrl("../../assets/fonts/nayori-clock/NayoriClock-Regular.ttf")
    }

    Row {
        id: clockRow
        anchors.fill: parent
        spacing: root.large ? 12 : 0

        DesktopLabel {
            objectName: "desktop-clock-time"
            y: root.large ? -Math.round(root.timeSize * 0.04) : 0
            width: root.large ? Math.max(0, parent.width - sideDate.width - divider.width - 2 * parent.spacing) : parent.width
            height: root.large ? parent.height : Math.max(0, parent.height - 20)
            tokens: root.tokens
            display: true
            color: root.clockAccent
            style: root.card ? Text.Normal : Text.Outline
            styleColor: Qt.alpha(root.outlineColor, 0.9)
            text: root.timeText
            horizontalAlignment: root.large ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: root.clockFontReady ? clockFont.name : root.tokens.type.display.family
            font.pixelSize: root.timeSize
            font.weight: Font.Normal
            font.letterSpacing: 0
            minimumPixelSize: 16
            fontSizeMode: root.editing ? Text.Fit : Text.HorizontalFit
            font.features: ({ "tnum": 1 })
            Accessible.name: "Часы, " + text
            Accessible.description: root.dateText
        }
        Rectangle {
            id: divider
            objectName: "desktop-clock-divider"
            visible: root.large
            width: root.large ? 1 : 0
            height: Math.min(parent.height * 0.75, sideDate.height + 16)
            y: (parent.height - height) / 2
            color: Qt.alpha(root.clockAccent, root.card ? 0.5 : 0.8)
        }
        Column {
            id: sideDate
            objectName: "desktop-clock-date-side"
            visible: root.large
            width: root.large ? Math.min(root.dateWidth, parent.width * 0.38) : 0
            height: childrenRect.height
            y: Math.round((parent.height - height) / 2)
            spacing: root.size === "huge" ? 5 : 2
            DesktopLabel {
                objectName: "desktop-clock-day"
                width: parent.width
                tokens: root.tokens
                text: root.dayText
                color: root.card ? root.tokens.color.text : root.clockAccent
                style: root.card ? Text.Normal : Text.Outline
                styleColor: Qt.alpha(root.outlineColor, 0.9)
                font.family: root.clockFontReady ? clockFont.name : root.tokens.type.display.family
                font.pixelSize: root.size === "huge" ? 68 : root.size === "extraLarge" ? 54 : 40
                font.weight: Font.Normal
                font.letterSpacing: 0
                lineHeight: 1
            }
            DesktopLabel {
                objectName: "desktop-clock-month"
                width: parent.width
                tokens: root.tokens
                text: root.monthText
                color: root.card ? root.tokens.color.textMuted : root.clockAccent
                style: root.card ? Text.Normal : Text.Outline
                styleColor: Qt.alpha(root.outlineColor, 0.9)
                font.pixelSize: root.size === "huge" ? 15 : root.size === "extraLarge" ? 13 : 12
            }
            DesktopLabel {
                objectName: "desktop-clock-weekday"
                width: parent.width
                tokens: root.tokens
                text: root.weekdayText
                color: root.card ? root.tokens.color.secondary : root.clockAccent
                style: root.card ? Text.Normal : Text.Outline
                styleColor: Qt.alpha(root.outlineColor, 0.9)
                font.pixelSize: root.size === "huge" ? 13 : root.size === "extraLarge" ? 12 : 10
            }
        }
    }
    DesktopLabel {
        objectName: "desktop-clock-date-compact"
        visible: !root.large
        anchors.bottom: parent.bottom
        width: parent.width
        tokens: root.tokens
        color: root.card ? root.tokens.color.textMuted : root.clockAccent
        style: root.card ? Text.Normal : Text.Outline
        styleColor: Qt.alpha(root.outlineColor, 0.9)
        horizontalAlignment: Text.AlignHCenter
        text: root.dateText
        font.pixelSize: 13
    }
}
