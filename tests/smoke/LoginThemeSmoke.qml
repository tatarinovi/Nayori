import QtQuick
import Quickshell
import "tokens"
import "services/lock"

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    property string first: ""
    Tokens { id: themeTokens }
    QtObject {
        id: walls
        property bool ready: false
        function wallpaper(output) { return {source: String(Qt.resolvedUrl("assets/wallpapers/nayori.png")), mode: output === "DP-1" ? "fill" : "fit"} }
    }
    LoginTheme {
        id: theme
        tokens: themeTokens
        wallpapers: walls
        settled: true
        primaryOutput: "DP-1"
        outputNames: ["DP-1", "HDMI-A-1"]
        destination: Quickshell.env("NAYORI_TEST_EXPORT")
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (++root.ticks > 70) throw new Error("theme export timeout: " + theme.error)
            if (root.stage === 0) {
                if (theme.lastWritten !== "") throw new Error("published before wallpapers ready")
                walls.ready = true
                root.stage = 1
            } else if (root.stage === 1 && theme.lastWritten !== "") {
                root.first = theme.lastWritten
                themeTokens.accentDerived = true
                themeTokens.accentSource = "#81C8BE"
                themeTokens.neutralDerived = true
                themeTokens.backgroundSource = "#172626"
                root.stage = 2
            } else if (root.stage === 2 && theme.lastWritten !== root.first) {
                if (theme.error !== "") throw new Error(theme.error)
                const colors = JSON.parse(theme.lastWritten).colors
                if (colors.background !== "#172626" || colors.accent !== String(themeTokens.color.accent)) throw new Error("not resolved dynamic roles")
                console.log("LOGIN_THEME_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
