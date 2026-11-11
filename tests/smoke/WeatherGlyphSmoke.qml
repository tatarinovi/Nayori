import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"

ShellRoot {
    id: test
    readonly property var codes: [113, 116, 119, 296, 326, 200, 248]
    readonly property var scenes: ["clear", "partlyCloudy", "cloudy", "rain", "snow", "storm", "fog"]
    Tokens { id: theme }
    function check(value, message) { if (!value) throw new Error(message) }
    FloatingWindow {
        visible: true
        implicitWidth: 280
        implicitHeight: 80
        color: theme.color.surfaceAlt
        Row {
            id: gallery
            anchors.centerIn: parent
            spacing: 20
            Repeater {
                model: test.codes
                WeatherGlyph {
                    required property int modelData
                    tokens: theme
                    weatherCode: modelData
                }
            }
        }
        WeatherGlyph { id: probe; tokens: theme; visible: false }
    }
    Timer {
        interval: 250
        running: true
        onTriggered: {
            for (let i = 0; i < test.codes.length; ++i) {
                probe.weatherCode = test.codes[i]
                test.check(probe.scene === test.scenes[i], "condition " + test.codes[i])
                test.check(probe.showArtwork, "valid weather visible")
            }
            for (let code of [null, undefined, "", " "]) {
                probe.weatherCode = code
                test.check(!probe.showArtwork, "empty weather hidden")
            }
            probe.weatherCode = 999
            test.check(probe.scene === "cloudy", "unknown condition fallback")
            probe.weatherCode = "113"
            test.check(probe.scene === "clear" && probe.showArtwork, "recovered weather")
            test.check(probe.implicitWidth === 14 && probe.implicitHeight === 14, "square native size")
            gallery.grabToImage(function(result) {
                result.saveToFile("/tmp/nayori-weather-glyphs.png")
                console.log("WEATHER_GLYPH_PASS")
                Qt.quit()
            })
        }
    }
}
