pragma ComponentBehavior: Bound
import QtQuick
import "../island"
import "WidgetLayout.js" as WidgetLayout

Item {
    id: root
    required property var tokens
    property var service: null
    property bool large: false

    readonly property var payload: service && !service.error ? WidgetLayout.readWeather(service.data) : null
    readonly property string message: {
        if (!service)
            return "Погода недоступна"
        if (service.error)
            return String(service.error)
        const city = String(service.city || "").trim()
        if (!city && !payload)
            return "Город не выбран"
        if (service.loading && !payload)
            return "Обновляем погоду"
        if (!payload)
            return "Нет данных о погоде"
        return ""
    }
    readonly property string temperature: payload && payload.temperature !== null ? WidgetLayout.temperatureText(payload.temperature) : ""
    readonly property string feels: payload && payload.feelsLike !== null ? "Ощущается как " + WidgetLayout.temperatureText(payload.feelsLike) : ""
    readonly property string humidity: payload && payload.humidity !== null && large ? "Влажность " + payload.humidity + "%" : ""

    Column {
        anchors.top: parent.top
        width: parent.width
        spacing: 4
        Item {
            width: parent.width
            height: root.tokens.type.small.size + 4
            visible: root.message === ""
            DesktopLabel {
                anchors.left: parent.left
                width: parent.width * 0.45
                tokens: root.tokens
                muted: true
                text: "Сейчас"
                font.pixelSize: root.tokens.type.small.size
            }
            DesktopLabel {
                anchors.right: parent.right
                width: parent.width * 0.55
                tokens: root.tokens
                muted: true
                horizontalAlignment: Text.AlignRight
                font.pixelSize: root.tokens.type.small.size
                text: root.service ? String(root.service.city || "") : ""
            }
        }
        DesktopLabel {
            width: parent.width
            visible: root.message !== ""
            tokens: root.tokens
            muted: true
            text: root.message
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Accessible.name: text
        }
        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft
            visible: root.message === ""
            Item {
                width: root.large ? 64 : 44
                height: width
                visible: root.payload && root.payload.weatherCode !== null
                readonly property int code: root.payload ? Number(root.payload.weatherCode) : 0
                readonly property bool clear: code === 113
                readonly property bool cloud: [116, 119, 122].indexOf(code) >= 0
                Rectangle {
                    visible: parent.clear || parent.cloud
                    width: parent.width * 0.48; height: width; radius: width / 2
                    anchors.top: parent.top; anchors.right: parent.right
                    color: root.tokens.color.secondary
                }
                Item {
                    visible: parent.cloud
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.58
                    Rectangle { x: parent.width * 0.04; y: parent.height * 0.35; width: parent.width * 0.92; height: parent.height * 0.55; radius: height / 2; color: root.tokens.color.accentSoft }
                    Rectangle { x: parent.width * 0.16; y: parent.height * 0.2; width: parent.width * 0.48; height: width; radius: width / 2; color: root.tokens.color.accentSoft }
                    Rectangle { x: parent.width * 0.42; y: 0; width: parent.width * 0.48; height: width; radius: width / 2; color: root.tokens.color.accentSoft }
                }
                WeatherGlyph {
                    visible: !parent.clear && !parent.cloud
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: parent.height * 0.7
                    tokens: root.tokens
                    weatherCode: root.payload ? root.payload.weatherCode : null
                }
            }
            Column {
                readonly property int glyphSpace: root.payload && root.payload.weatherCode !== null ? (root.large ? 72 : 52) : 0
                width: Math.max(0, parent.width - glyphSpace)
                spacing: 2
                DesktopLabel {
                    width: parent.width
                    tokens: root.tokens
                    display: true
                    text: root.temperature !== "" ? root.temperature : "Нет температуры"
                    font.pixelSize: root.large ? 46 : 27
                    lineHeight: 1
                    Accessible.name: "Погода, " + text
                }
                DesktopLabel {
                    width: parent.width
                    visible: root.payload && root.payload.description !== ""
                    tokens: root.tokens
                    display: true
                    font.pixelSize: root.large ? 18 : 13
                    text: root.payload ? root.payload.description : ""
                }
                DesktopLabel {
                    width: parent.width
                    visible: false
                    tokens: root.tokens
                    muted: true
                    text: root.feels
                    font.pixelSize: root.tokens.type.small.size
                }
                DesktopLabel {
                    width: parent.width
                    visible: false
                    tokens: root.tokens
                    muted: true
                    text: root.humidity
                    font.pixelSize: root.tokens.type.small.size
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            visible: root.message === "" && root.payload && root.payload.forecast.length > 0
            color: Qt.alpha(root.tokens.color.text, 0.16)
        }
        Row {
            objectName: "desktop-weather-forecast"
            width: parent.width
            spacing: 0
            visible: root.message === "" && root.payload && root.payload.forecast.length > 0
            Repeater {
                model: root.payload ? root.payload.forecast : []
                delegate: Column {
                    id: day
                    required property var modelData
                    width: parent.width / Math.max(1, root.payload.forecast.length)
                    spacing: 2
                    readonly property string span: {
                        const low = WidgetLayout.temperatureText(modelData.min)
                        const high = WidgetLayout.temperatureText(modelData.max)
                        if (root.large && low && high)
                            return low + "\u00A0\u2013\u00A0" + high
                        return high || low
                    }
                    DesktopLabel {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        tokens: root.tokens
                        muted: true
                        text: day.modelData.label
                        visible: root.large && text !== ""
                        font.pixelSize: root.tokens.type.small.size
                    }
                    DesktopLabel {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        tokens: root.tokens
                        text: root.large || !day.modelData.label ? day.span : day.modelData.label + " " + day.span
                        font.pixelSize: root.large ? root.tokens.type.body.size : root.tokens.type.small.size
                        Accessible.name: (day.modelData.label || "Прогноз") + ", " + text
                    }
                }
            }
        }
    }
}
