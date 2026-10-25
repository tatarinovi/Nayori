import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var tokens
    property int bottomInset: 88
    property bool animationsEnabled: true
    // true: за окнами, над обоями; false: поверх окон (но под меню, лаунчером и панелью)
    property bool desktopOnly: false
    readonly property real companionScale: Math.max(0.1, Math.min(1,
        (screen ? screen.width - 32 : 280) / 280,
        (screen ? screen.height - bottomInset - 48 : 534) / 534))

    anchors { right: true; bottom: true }
    margins { right: 20; bottom: root.bottomInset }
    implicitWidth: Math.round(280 * companionScale)
    implicitHeight: Math.round(534 * companionScale)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    // Naomi украшает рабочий стол; весь ввод проходит сквозь окно.
    mask: Region {}
    WlrLayershell.layer: root.desktopOnly ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.namespace: "nayori-companion"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NaomiIllustration {
        tokens: root.tokens
        anchors.fill: parent
        active: true
        animationsEnabled: root.animationsEnabled
        followPointer: false
    }
}
