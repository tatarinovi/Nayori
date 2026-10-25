import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"

ShellRoot {
    id: test
    readonly property var scenes: ["clear", "cloudy", "rain", "snow", "storm", "fog"]
    readonly property var codes: [113, 119, 296, 326, 200, 248]
    property int sceneIndex: 0
    Tokens { id: theme }
    function illustration(item) {
        if (item.objectName === "weatherIllustration") return item
        for (let child of item.children) {
            const found = illustration(child)
            if (found) return found
        }
        return null
    }
    function check(value, message) { if (!value) throw new Error(message) }
    function setWeather() { dashboard.weather = {weatherCode: codes[sceneIndex], temp_C: "18", FeelsLikeC: "17"} }
    FloatingWindow {
        visible: true
        implicitWidth: 680
        implicitHeight: 450
        IslandDashboard { id: dashboard; anchors.fill: parent; tokens: theme }
    }
    Component.onCompleted: setWeather()
    Timer {
        id: captureTimer
        interval: 650
        running: true
        repeat: true
        onTriggered: {
            const art = test.illustration(dashboard)
            test.check(dashboard.weatherScene === test.scenes[test.sceneIndex], "weather condition mapping")
            test.check(art && art.status === Image.Ready, "weather image loaded: " + test.scenes[test.sceneIndex])
            captureTimer.stop()
            dashboard.grabToImage(function(result) {
                result.saveToFile("/tmp/nayori-weather-" + test.scenes[test.sceneIndex] + ".png")
                test.sceneIndex++
                if (test.sceneIndex < test.scenes.length) {
                    test.setWeather()
                    captureTimer.start()
                } else {
                    dashboard.weatherError = "Test error"
                    test.check(art.source.toString() === "", "no illustration for failed weather")
                    dashboard.weatherError = ""
                    dashboard.weather = null
                    test.check(art.source.toString() === "", "no illustration without weather")
                    console.log("WEATHER_ARTWORK_PASS")
                    Qt.quit()
                }
            })
        }
    }
}
