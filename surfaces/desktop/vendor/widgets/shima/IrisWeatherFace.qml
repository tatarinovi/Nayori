import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts





IrisWidgetFace {
    readonly property var nayoriIrisWeatherFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property bool ready: nayoriIrisWeatherFace.weather.enabled && !String(nayoriIrisWeatherFace.weather.data?.temp ?? "--").startsWith("--")
    readonly property string glyph: nayoriIrisWeatherFace.icons.getWeatherIcon(nayoriIrisWeatherFace.weather.data?.wCode, nayoriIrisWeatherFace.weather.isNightNow()) ?? "cloud"
    readonly property color sky: nayoriIrisWeatherFace.irisStyle.skyLight(root.glyph)
    readonly property string city: root.widget.showLocation && nayoriIrisWeatherFace.weather.showVisibleCity ? nayoriIrisWeatherFace.weather.visibleCity : ""
    readonly property string condition: nayoriIrisWeatherFace.faceData.capitalized(String(nayoriIrisWeatherFace.weather.data?.description ?? ""))
    readonly property string range: {
        const high = root.degrees(nayoriIrisWeatherFace.weather.data?.tempMax)
        const low = root.degrees(nayoriIrisWeatherFace.weather.data?.tempMin)
        return high.length > 0 && low.length > 0 ? nayoriIrisWeatherFace.translation.tr("H:%1  L:%2").arg(high).arg(low) : ""
    }
    readonly property var hours: Array.from(nayoriIrisWeatherFace.weather.data?.hourly ?? []).slice(0, root.large ? 6 : 5)
    readonly property var days: Array.from(nayoriIrisWeatherFace.weather.data?.forecast ?? []).slice(0, 5)
    readonly property var lows: root.days.map(day => Number(day.loVal)).filter(Number.isFinite)
    readonly property var highs: root.days.map(day => Number(day.hiVal)).filter(Number.isFinite)
    readonly property real weekLow: root.lows.length > 0 ? Math.min(...root.lows) : 0
    readonly property real weekHigh: root.highs.length > 0 ? Math.max(...root.highs) : 1

    function degrees(value: var): string {
        const text = String(value ?? "").trim()
        if (text.length === 0 || text.startsWith("--"))
            return ""
        return text.replace(/°[CF]$/, "°").replace(/([0-9])$/, "$1°")
    }

    light: root.ready ? root.sky : "transparent"

    component Now: ColumnLayout {
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.city.length > 0
            text: root.city
            size: 13.5
            weight: Font.DemiBold
        }
        FaceFigure {
            face: root
            Layout.fillWidth: true
            text: root.widget.temperatureText
            size: root.large ? 50 : 44
        }
    }

    component Condition: ColumnLayout {
        spacing: root.dp(1)
        MaterialSymbol {
            text: root.glyph
            fill: 1
            iconSize: root.px(20)
            color: root.sky
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.condition
            size: 12.5
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.range.length > 0 || nayoriIrisWeatherFace.weather.stale
            text: !nayoriIrisWeatherFace.weather.stale ? root.range
                : !nayoriIrisWeatherFace.network.online ? nayoriIrisWeatherFace.translation.tr("Offline · %1").arg(nayoriIrisWeatherFace.weather.updatedLabel)
                : nayoriIrisWeatherFace.translation.tr("Updated %1").arg(nayoriIrisWeatherFace.weather.updatedLabel)
            color: nayoriIrisWeatherFace.weather.stale ? root.inkTertiary : root.inkSecondary
            size: 12
        }
    }

    component Hours: RowLayout {
        spacing: 0
        Repeater {
            model: root.hours
            ColumnLayout {
                id: hour
                required property var modelData
                required property int index
                readonly property string glyph: nayoriIrisWeatherFace.icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: root.dp(4)
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: hour.index === 0 ? nayoriIrisWeatherFace.translation.tr("Now")
                        : nayoriIrisWeatherFace.weather.displayTime(hour.modelData.label, hour.modelData.minuteOfDay)
                    color: hour.index === 0 ? root.ink : root.inkSecondary
                    size: 11.5
                    weight: hour.index === 0 ? Font.DemiBold : Font.Medium
                    font.features: ({ "tnum": 1 })
                }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: hour.glyph
                    fill: 1
                    iconSize: root.px(19)
                    color: nayoriIrisWeatherFace.irisStyle.skyLight(hour.glyph)
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: root.degrees(hour.modelData.temp)
                    size: 13
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    ColumnLayout {
        visible: !root.ready
        anchors.centerIn: parent
        width: parent.width
        spacing: root.dp(6)
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "cloud_off"
            iconSize: root.px(28)
            color: root.inkTertiary
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !nayoriIrisWeatherFace.weather.enabled ? nayoriIrisWeatherFace.translation.tr("Weather is off")
                : !nayoriIrisWeatherFace.network.online ? nayoriIrisWeatherFace.network.offlineReason
                : nayoriIrisWeatherFace.translation.tr("Looking for the sky…")
            color: root.inkSecondary
            size: 12.5
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }

    ColumnLayout {
        visible: root.ready && root.small
        anchors.fill: parent
        spacing: 0
        Now { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        Condition { Layout.fillWidth: true }
    }

    RowLayout {
        visible: root.ready && root.medium
        anchors.fill: parent
        spacing: root.dp(14)
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.36
            Layout.maximumWidth: root.contentWidth * 0.36
            Layout.fillHeight: true
            spacing: 0
            Now { Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            Condition { Layout.fillWidth: true }
        }
        Hours {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        visible: root.ready && root.large
        anchors.fill: parent
        spacing: root.dp(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(12)
            Now { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            Condition { Layout.preferredWidth: root.contentWidth * 0.42; Layout.alignment: Qt.AlignBottom }
        }
        Hours { Layout.fillWidth: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        Repeater {
            model: root.days
            RowLayout {
                id: day
                required property var modelData
                readonly property string glyph: nayoriIrisWeatherFace.icons.getWeatherIcon(day.modelData.code, false) ?? "cloud"
                readonly property real span: Math.max(1, root.weekHigh - root.weekLow)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(10)
                FaceText {
                    face: root
                    Layout.preferredWidth: root.contentWidth * 0.24
                    text: nayoriIrisWeatherFace.faceData.capitalized(day.modelData.dayName)
                    size: 13
                    weight: Font.DemiBold
                }
                MaterialSymbol {
                    Layout.preferredWidth: root.px(22)
                    text: day.glyph
                    fill: 1
                    iconSize: root.px(18)
                    color: nayoriIrisWeatherFace.irisStyle.skyLight(day.glyph)
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(30)
                    horizontalAlignment: Text.AlignRight
                    text: root.degrees(day.modelData.lo)
                    color: root.inkSecondary
                    size: 13
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.dp(5)
                    radius: height / 2
                    color: root.fill
                    Rectangle {
                        x: parent.width * (Number(day.modelData.loVal) - root.weekLow) / day.span
                        width: Math.max(parent.height, parent.width * (Number(day.modelData.hiVal) - Number(day.modelData.loVal)) / day.span)
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: nayoriIrisWeatherFace.irisStyle.identity.sky }
                            GradientStop { position: 1; color: nayoriIrisWeatherFace.irisStyle.identity.orange }
                        }
                    }
                }
                FaceText {
                    face: root
                    Layout.preferredWidth: root.px(30)
                    text: root.degrees(day.modelData.hi)
                    size: 13
                    weight: Font.DemiBold
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
