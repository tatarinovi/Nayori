import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io



Item {
    readonly property var nayoriWeatherFaceFull: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 340
    property real minHeight: 160
    property real maxWidth: 820
    property real maxHeight: 500
    property real minAspect: 1.6
    property real maxAspect: 1.6
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property real baseRef: Math.min(root.height, root.width * 0.6)
    property real dynMargin: Math.max(12, baseRef * 0.09)
    property real dynSpacing: Math.max(8, baseRef * 0.05)
    property real innerHeight: Math.max(0, root.height - dynMargin * 2)

    property real iconTop: Math.max(28, Math.min(78, innerHeight * 0.36))
    property real tempHuge: Math.max(24, Math.min(64, innerHeight * 0.3))
    property real textCity: Math.max(13, Math.min(20, innerHeight * 0.105))
    property real textDesc: Math.max(11, Math.min(16, innerHeight * 0.085))
    property real textFeels: Math.max(10, Math.min(14, innerHeight * 0.085))
    property real forecastTemp: Math.max(11, Math.min(18, innerHeight * 0.085))
    property real forecastIcon: Math.max(20, Math.min(32, innerHeight * 0.15))
    property real forecastTime: Math.max(9, Math.min(13, innerHeight * 0.065))
    property int forecastCount: root.width >= 360 ? 4 : 3

    property var weatherData: nayoriWeatherFaceFull.weather.data
    property bool hasLoadedOnce: nayoriWeatherFaceFull.weather.isReady
    property bool isLoading: nayoriWeatherFaceFull.weather.isLoading || !nayoriWeatherFaceFull.weather.isReady

    property string currentHex: nayoriWeatherFaceFull.weather.currentHex
    property color accentColor: (currentHex && currentHex.length === 7) ? currentHex : nayoriWeatherFaceFull.pythonTheme.mauve

    property var hourlyList: []

    property real cardRadius: nayoriWeatherFaceFull.pythonTheme.clampedBorderRadius

    function formatHour(timeStr) {
        if (!timeStr) return "";
        let str = String(timeStr).trim();
        if (str.toLowerCase().indexOf("am") !== -1 || str.toLowerCase().indexOf("pm") !== -1) {
            return str;
        }
        let hour = 0;
        if (str.indexOf(":") !== -1) {
            hour = parseInt(str.split(":")[0], 10);
        } else {
            let num = parseInt(str, 10);
            if (!isNaN(num)) {
                hour = num >= 100 ? Math.floor(num / 100) : num;
            }
        }
        if (isNaN(hour)) return str;

        if (nayoriWeatherFaceFull.dateTime.is12Hour) {
            let period = hour >= 12 ? "PM" : "AM";
            let h12 = hour % 12;
            if (h12 === 0) h12 = 12;
            return h12 + period;
        }

        return (hour < 10 ? "0" + hour : hour) + ":00";
    }

    function getFeelsLike() {
        if (!weatherData) return nayoriWeatherFaceFull.weather.currentTemp !== "" ? Math.round(parseFloat(nayoriWeatherFaceFull.weather.currentTemp)) + "°" : "--°";
        let fl = weatherData.current_feels_like ?? weatherData.feels_like ?? weatherData.current_feelslike;
        if (fl !== undefined && fl !== null && fl !== "") {
            return Math.round(parseFloat(fl)) + "°";
        }
        if (weatherData.forecast && weatherData.forecast[0]) {
            let f0 = weatherData.forecast[0];
            if (f0.feels_like !== undefined) return Math.round(parseFloat(f0.feels_like)) + "°";
            if (f0.hourly && f0.hourly[0] && f0.hourly[0].feels_like !== undefined) {
                return Math.round(parseFloat(f0.hourly[0].feels_like)) + "°";
            }
        }
        if (nayoriWeatherFaceFull.weather.currentTemp !== "") {
            return Math.round(parseFloat(nayoriWeatherFaceFull.weather.currentTemp)) + "°";
        }
        return "--°";
    }

    function updateForecastData() {
        if (!weatherData || !weatherData.forecast || !Array.isArray(weatherData.forecast) || weatherData.forecast.length === 0) {
            hourlyList = [];
            return;
        }

        let allHourly = [];
        for (let d = 0; d < weatherData.forecast.length; d++) {
            if (weatherData.forecast[d] && weatherData.forecast[d].hourly) {
                allHourly = allHourly.concat(weatherData.forecast[d].hourly);
            }
        }

        if (allHourly.length === 0) {
            hourlyList = [];
            return;
        }

        let ch = nayoriWeatherFaceFull.dateTime.now.getHours();
        let bestIdx = 0;
        let minDiff = 999;
        for (let i = 0; i < allHourly.length; i++) {
            let timeStr = allHourly[i].time || "00:00";
            let h = parseInt(timeStr.split(":")[0], 10);
            if (isNaN(h)) {
                let n = parseInt(timeStr, 10);
                h = n >= 100 ? Math.floor(n / 100) : n;
            }
            let diff = h - ch;
            if (diff >= 0 && diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }

        if (minDiff === 999) {
            for (let i = 0; i < allHourly.length; i++) {
                let timeStr = allHourly[i].time || "00:00";
                let h = parseInt(timeStr.split(":")[0], 10);
                if (isNaN(h)) {
                    let n = parseInt(timeStr, 10);
                    h = n >= 100 ? Math.floor(n / 100) : n;
                }
                let diff = Math.abs(h - ch);
                if (diff < minDiff) {
                    minDiff = diff;
                    bestIdx = i;
                }
            }
        }

        hourlyList = allHourly.slice(bestIdx, bestIdx + 4);
    }

    onWeatherDataChanged: updateForecastData()

    Connections {
        target: nayoriWeatherFaceFull.dateTime
        function onHourChanged() {
            root.updateForecastData();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriWeatherFaceFull.pythonTheme.surface0, nayoriWeatherFaceFull.pythonTheme.elementOpacity)
        radius: root.cardRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            visible: !root.ryokuBare
        }

        LoaderIcon {
            anchors.centerIn: parent
            width: Math.max(28, Math.min(56, root.baseRef * 0.3))
            height: width
            accentColor: nayoriWeatherFaceFull.pythonTheme.mauve
            running: root.isLoading
            visible: root.isLoading
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.dynMargin
            spacing: root.dynSpacing
            visible: !root.isLoading

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 0

                Text {
                    text: nayoriWeatherFaceFull.weather.currentIcon
                    font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                    font.pixelSize: Math.round(root.iconTop)
                    color: root.accentColor
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                }

                Item {
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
                    spacing: 2

                    Text {
                        text: nayoriWeatherFaceFull.weather.currentTemp !== "" ? Math.round(parseFloat(nayoriWeatherFaceFull.weather.currentTemp)) + "°" : "--°"
                        font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                        font.pixelSize: Math.round(root.tempHuge)
                        font.weight: Font.Black
                        color: nayoriWeatherFaceFull.pythonTheme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        text: nayoriWeatherFaceFull.i18n.t("calendar.weather.feels") + " " + root.getFeelsLike()
                        font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                        font.pixelSize: Math.round(root.textFeels)
                        font.weight: Font.Medium
                        color: nayoriWeatherFaceFull.pythonTheme.subtext0
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.3
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: 2

                    Text {
                        text: nayoriWeatherFaceFull.location.city && nayoriWeatherFaceFull.location.city !== "" ? nayoriWeatherFaceFull.location.city : (root.weatherData && root.weatherData.city ? root.weatherData.city : "Unknown")
                        font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                        font.pixelSize: Math.round(root.textCity)
                        font.weight: Font.Bold
                        color: nayoriWeatherFaceFull.pythonTheme.text
                        horizontalAlignment: Text.AlignRight
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.weatherData && root.weatherData.forecast && root.weatherData.forecast[0] && root.weatherData.forecast[0].desc ? root.weatherData.forecast[0].desc : (nayoriWeatherFaceFull.weather.data && nayoriWeatherFaceFull.weather.data.desc ? nayoriWeatherFaceFull.weather.data.desc : "")
                        font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                        font.pixelSize: Math.round(root.textDesc)
                        font.weight: Font.Medium
                        color: nayoriWeatherFaceFull.pythonTheme.subtext0
                        horizontalAlignment: Text.AlignRight
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                    spacing: Math.max(6, root.dynSpacing * 0.9)

                    Repeater {
                        model: root.hourlyList.slice(0, root.forecastCount)
                        delegate: ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                            spacing: 4

                            Text {
                                text: Math.round(parseFloat(modelData.temp)) + "°"
                                color: nayoriWeatherFaceFull.pythonTheme.subtext0
                                font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                                font.pixelSize: Math.round(root.forecastTemp)
                                font.weight: Font.Medium
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                transform: Translate { x: 2 }
                            }

                            Text {
                                text: modelData.icon
                                color: modelData.hex && modelData.hex.length === 7 ? modelData.hex : root.accentColor
                                font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                                font.pixelSize: Math.round(root.forecastIcon)
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                                transform: Translate { x: -2 }
                            }

                            Text {
                                text: root.formatHour(modelData.time)
                                color: nayoriWeatherFaceFull.pythonTheme.subtext0
                                font.family: nayoriWeatherFaceFull.pythonTheme.fontFamily
                                font.pixelSize: Math.round(root.forecastTime)
                                font.weight: Font.Normal
                                Layout.alignment: Qt.AlignHCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
