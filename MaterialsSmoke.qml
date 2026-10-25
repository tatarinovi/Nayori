pragma ComponentBehavior: Bound
//@ pragma AppId nayori-materials-test
import QtQuick
import Quickshell
import Quickshell.Wayland
import "tokens"
import "surfaces/settings"

ShellRoot {
    id: test
    property int step: 0
    Tokens { id: theme }
    SettingsWindow { id: surface; tokens: theme; visible: true }
    PanelWindow {
        id: panel
        anchors { top: true; left: true }
        margins.top: 40
        implicitWidth: 168
        implicitHeight: 48
        color: "transparent"
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-materials-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        property var materialRegion: Region {
            Region { item: firstIsland; radius: 24 }
            Region { item: secondIsland; radius: 24 }
        }
        BackgroundEffect.blurRegion: theme.frosted ? panel.materialRegion : null
        Rectangle { id: firstIsland; width: 80; height: 48; radius: 24; color: theme.material.panel }
        Rectangle { id: secondIsland; x: 88; width: 80; height: 48; radius: 24; color: theme.material.panel }
    }
    function check(ok, text) {
        if (!ok) { console.error("MATERIALS_FAIL " + text); Qt.exit(1) }
    }
    Timer {
        interval: 180
        running: true
        repeat: true
        onTriggered: {
            if (test.step === 0) {
                test.check(!theme.frosted && theme.material.panel === theme.color.surfaceAlt
                    && theme.material.dense === theme.color.background, "Solid preserves graphite palette")
                test.check(!surface.BackgroundEffect.blurRegion, "Solid has no blur request")
                theme.surfaceStyle = "frosted"
            } else if (test.step === 1) {
                test.check(surface.BackgroundEffect.blurRegion !== null, "Frosted requests background blur")
                test.check(panel.BackgroundEffect.blurRegion !== null, "composite panel blur region")
                test.check(theme.material.panel.a < theme.material.island.a && theme.material.island.a < theme.material.dense.a,
                    "bottom, island and dense surfaces have distinct opacity")
                test.check(theme.color.text.a === 1 && theme.color.textMuted.a === 1, "text remains opaque")
                theme.surfaceStyle = "solid"
            } else if (test.step === 2) {
                test.check(!surface.BackgroundEffect.blurRegion && theme.material.dense.a === 1, "return to Solid removes blur and transparency")
                console.log("MATERIALS_PASS")
                Qt.quit()
            }
            test.step++
        }
    }
}
