import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var tokens
    property string companionStyle: "current"
    readonly property int designHeight: companionStyle === "pixel-art" ? 400 : 534
    property int bottomInset: 88
    property bool animationsEnabled: true
    // true: за окнами, над обоями; false: поверх окон (но под меню, лаунчером и панелью)
    property bool desktopOnly: false
    // true: окно ловит курсор над головой Naomi (поглаживание). Клики по этому небольшому
    // эллипсу не проходят сквозь неё. false: окно целиком прозрачно для ввода.
    property bool reactToPointer: true
    // Комментировать системные события (нагрузка, окна, батарея, сеть, обновление, бездействие, ночь).
    // false — источники отключаются, реплики не копятся. Приветствие и поглаживание не зависят.
    property bool systemLines: true
    // Над иллюстрацией — место под облачко с репликой (до пяти строк), оно прозрачно для ввода.
    readonly property int bubbleSpace: 128
    readonly property real companionScale: Math.max(0.1, Math.min(1,
        (screen ? screen.width - 32 : 280) / 280,
        (screen ? screen.height - bottomInset - 48 - bubbleSpace : designHeight) / designHeight))
    readonly property int illustrationWidth: Math.round(280 * companionScale)
    readonly property int illustrationHeight: Math.round(designHeight * companionScale)

    // Сама Naomi с облаком и поглаживанием; нужна тестам и снимкам.
    readonly property alias scene: companion
    // Показать облако с репликой. holdSeconds <= 0 — по длине текста. Для системных событий.
    function say(text: string, holdSeconds: real): bool { return companion.say(text, holdSeconds || 0) }

    anchors { right: true; bottom: true }
    margins { right: 20; bottom: root.bottomInset }
    implicitWidth: illustrationWidth
    implicitHeight: illustrationHeight + bubbleSpace
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    // Весь ввод проходит сквозь окно, кроме эллипса головы, когда реакция на курсор включена.
    // Облачко, тело и пустое место над головой вход не принимают.
    mask: root.reactToPointer ? headMask : emptyMask
    WlrLayershell.layer: root.desktopOnly ? WlrLayer.Bottom : WlrLayer.Top
    WlrLayershell.namespace: "nayori-companion"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // qs ipc call naomi say "Текст": показать облако. Работает, пока Naomi показана на рабочем столе.
    IpcHandler {
        target: "naomi"
        function say(text: string): bool { return companion.say(text, 0) }
        // qs ipc call naomi trigger cpu — системная реплика вручную, без кулдаунов и независимо от настройки.
        function trigger(kind: string): bool { return companion.trigger(kind, undefined) }
        // qs ipc call naomi triggerValue battery 5 — то же с заряженностью (battery) или часом 0–5 (night).
        function triggerValue(kind: string, value: string): bool { return companion.trigger(kind, value) }
        // qs ipc call naomi triggers — список видов.
        function triggers(): string { return companion.controller.triggerKinds().join(" ") }
    }

    // Источники системных событий: CPU, niri, UPower, сеть, ввод, процессы обновления.
    NaomiSystemSources {
        controller: companion.controller
        enabled: root.systemLines
    }

    Region { id: emptyMask }
    Region { id: headMask; item: headZone; shape: RegionShape.Ellipse }
    // Область наведения: зона головы из иллюстрации в координатах окна.
    Item {
        id: headZone
        x: Math.round(companion.headRect.x)
        y: Math.round(companion.headRect.y)
        width: Math.round(companion.headRect.width)
        height: Math.round(companion.headRect.height)
    }

    NaomiCompanion {
        id: companion
        companionStyle: root.companionStyle
        tokens: root.tokens
        anchors.fill: parent
        active: true
        animationsEnabled: root.animationsEnabled
        reactToPointer: root.reactToPointer
        systemLines: root.systemLines
        followPointer: false
        illustrationWidth: root.illustrationWidth
        illustrationHeight: root.illustrationHeight
    }
}
