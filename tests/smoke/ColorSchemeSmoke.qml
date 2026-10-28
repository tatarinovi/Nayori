pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import "tokens"
import "tokens/AccentRoles.js" as AccentRoles
import "surfaces/settings"

ShellRoot {
    id: test
    Tokens { id: theme; colorScheme: "light"; animationsEnabled: false }
    Window {
        visible: true
        width: 1100
        height: 800
        Settings {
            id: settings
            anchors.fill: parent
            tokens: theme
            currentPage: 2
            colorScheme: theme.colorScheme
            onColorSchemeChangedRequested: scheme => theme.colorScheme = scheme
        }
    }
    function check(ok, message) {
        if (!ok) { console.error("COLOR_SCHEME_FAIL " + message); Qt.exit(1) }
    }
    function contrast() {
        for (const surface of [theme.color.background, theme.color.surface, theme.color.surfaceAlt]) {
            check(AccentRoles.contrast(theme.color.text, surface) >= 4.5, "body text contrast")
            check(AccentRoles.contrast(theme.color.textMuted, surface) >= 4.5, "muted text contrast")
        }
        check(AccentRoles.contrast(theme.color.accent, theme.color.surfaceAlt) >= 4.5, "accent contrast")
        check(AccentRoles.contrast(theme.color.accentText, theme.color.accent) >= 4.5, "accent ink")
        check(AccentRoles.contrast(theme.color.accentSoftText, theme.color.accentSoft) >= 4.5, "soft accent ink")
    }
    Timer {
        interval: 600
        running: true
        onTriggered: {
            test.contrast()
            theme.neutralDerived = true
            for (const source of ["#121217", "#FF0000", "#00FF00", "#0000FF", "#FFFFFF"]) {
                theme.backgroundSource = source
                theme.surfaceSource = source
                theme.surfaceAltSource = source
                theme.accentSource = source
                theme.accentDerived = true
                test.contrast()
                theme.surfaceStyle = "frosted"
                test.check(theme.material.panel.r > 0.8 && theme.material.panel.a < theme.material.island.a
                    && theme.material.island.a < theme.material.dense.a, "light frosted material densities")
                theme.surfaceStyle = "solid"
            }
            theme.neutralDerived = false
            theme.accentDerived = false
            theme.colorScheme = "dark"
            test.check(String(theme.color.background) === "#121217" && String(theme.color.accent) === "#c0afd1", "dark palette round trip")
            theme.colorScheme = "light"
            const destination = Quickshell.env("NAYORI_THEME_PREVIEW")
            if (destination) {
                settings.grabToImage(result => {
                    test.check(result.saveToFile(destination), "preview saved")
                    console.log("COLOR_SCHEME_PASS")
                    Qt.quit()
                })
            } else {
                console.log("COLOR_SCHEME_PASS")
                Qt.quit()
            }
        }
    }
}
