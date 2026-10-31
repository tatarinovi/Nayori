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
        anchors.fill: parent
        spacing: root.large ? 10 : 5
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
            visible: root.message === ""
            Item {
                width: root.large ? 54 : 36
                height: width
                visible: root.payload && root.payload.weatherCode !== null
                WeatherGlyph {
                    anchors.fill: parent
                    tokens: root.tokens
                    weatherCode: root.payload ? root.payload.weatherCode : null
                }
            }
            Column {
                readonly property int glyphSpace: root.payload && root.payload.weatherCode !== null ? (root.large ? 62 : 44) : 0
                width: Math.max(0, parent.width - glyphSpace)
                spacing: 2
                DesktopLabel {
                    width: parent.width
                    tokens: root.tokens
                    display: true
                    text: root.temperature !== "" ? root.temperature : "Нет температуры"
                    font.pixelSize: root.large ? 40 : 27
                    lineHeight: 1
                    Accessible.name: "Погода, " + text
                }
                DesktopLabel {
                    width: parent.width
                    visible: root.payload && root.payload.description !== ""
                    tokens: root.tokens
                    text: root.payload ? root.payload.description : ""
                }
                DesktopLabel {
                    width: parent.width
                    visible: root.large && root.feels !== ""
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
                        visible: text !== ""
                        font.pixelSize: root.tokens.type.small.size
                    }
                    DesktopLabel {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        tokens: root.tokens
                        text: day.span
                        Accessible.name: (day.modelData.label || "Прогноз") + ", " + text
                    }
                }
            }
        }
    }
}
