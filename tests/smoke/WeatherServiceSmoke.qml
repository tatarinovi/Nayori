pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "services/weather"
import "surfaces/island"
import "tokens"

ShellRoot {
    id: test
    property int step: 0
    property int ticks: 0
    property var dashboard: null
    Tokens { id: theme }
    Item { id: consumerScene }
    property Component dashboardFactory: Component {
        IslandDashboard {
            tokens: theme
            testMode: true
            weatherCity: forecast.city
            weather: forecast.data
            weatherError: forecast.error
            weatherLoading: forecast.loading
            onWeatherRefreshRequested: forecast.refresh()
        }
    }
    property double prior: 0
    property double intervalUpdatedAt: 0
    WeatherService {
        id: forecast
        city: "valid"
        refreshMinutes: 1
        minuteDurationMs: 160
        requestCommand: ["python3", Quickshell.env("NAYORI_WEATHER_FAKE"), Quickshell.env("NAYORI_WEATHER_LOG")]
    }
    function check(value, message) {
        if (!value) {
            console.error("WEATHER_SERVICE_FAIL " + message)
            Qt.exit(1)
        }
    }
    Timer {
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            test.ticks++
            test.check(test.ticks < 900, "timeout at step " + test.step)
            if (test.step === 0 && forecast.data) {
                test.prior = forecast.updatedAt
                test.step++
            } else if (test.step === 1 && forecast.updatedAt > test.prior) {
                // A second fetch occurred with no window or UI consumer.
                forecast.minuteDurationMs = 10000
                forecast.requestCommand = ["python3", Quickshell.env("NAYORI_WEATHER_FAKE"), Quickshell.env("NAYORI_WEATHER_LOG"), "bad"]
                forecast.refresh()
                test.step++
            } else if (test.step === 2 && forecast.error && !forecast.loading) {
                test.check(forecast.data && forecast.data.temp_C === "18", "malformed response erased cache")
                forecast.requestCommand = ["python3", Quickshell.env("NAYORI_WEATHER_FAKE"), Quickshell.env("NAYORI_WEATHER_LOG"), "fail"]
                forecast.refresh()
                test.step++
            } else if (test.step === 3 && forecast.error && !forecast.loading) {
                test.check(forecast.data && forecast.data.temp_C === "18", "failed request erased cache")
                forecast.requestCommand = ["python3", Quickshell.env("NAYORI_WEATHER_FAKE"), Quickshell.env("NAYORI_WEATHER_LOG")]
                forecast.city = "slow"
                test.step++
            } else if (test.step === 4 && forecast.loading) {
                forecast.city = "latest"
                test.check(forecast.data === null, "city change did not clear cache")
                forecast.refresh()
                test.step++
            } else if (test.step === 5 && forecast.data) {
                test.check(forecast.data.city === "latest", "stale city accepted")
                test.intervalUpdatedAt = forecast.updatedAt
                test.dashboard = test.dashboardFactory.createObject(consumerScene)
                test.check(test.dashboard.weather.city === "latest", "cached data on dashboard open")
                test.dashboard.destroy()
                test.step = 10
            } else if (test.step === 10) {
                test.dashboard = test.dashboardFactory.createObject(consumerScene)
                test.check(test.dashboard.weather.city === "latest" && !forecast.loading, "reopening starts no fetch")
                test.dashboard.destroy()
                forecast.refreshMinutes = 180
                forecast.minuteDurationMs = 1
                test.prior = test.ticks
                test.step = 8
            } else if (test.step === 8 && test.ticks - test.prior > 8) {
                forecast.refreshMinutes = 180 - 1
                test.prior = test.ticks
                test.step = 9
            } else if (test.step === 9 && test.ticks - test.prior > 11) {
                test.check(forecast.updatedAt === test.intervalUpdatedAt && !forecast.loading, "interval change did not reset schedule")
                forecast.city = ""
                forecast.minuteDurationMs = 20
                test.prior = test.ticks
                test.step = 6
            } else if (test.step === 6 && test.ticks - test.prior > 15) {
                test.check(!forecast.loading && forecast.data === null, "empty city requested")
                forecast.enabled = false
                forecast.city = "disabled"
                test.prior = test.ticks
                test.step++
            } else if (test.step === 7 && test.ticks - test.prior > 15) {
                test.check(!forecast.loading, "disabled requested")
                console.log("WEATHER_SERVICE_PASS")
                Qt.quit()
            }
        }
    }
}
