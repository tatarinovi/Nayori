import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../services/ui"

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
    // Нижний угол: "left" или "right".
    property string side: "right"
    FullscreenGuard { id: fullscreenGuard; screen: root.screen; tokens: root.tokens }
    visible: !fullscreenGuard.blocked && fullscreenGuard.reveal > 0
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
    // Напоминание сразу: water, eyes, move. Расписание не сдвигается.
    function remind(kind: string): bool { return companion.remind(kind) }

    // Сначала ставится новый край, потом снимается старый. Иначе на один
    // проход привязки окно остаётся без левого и правого края, и Quickshell падает.
    anchors.bottom: true
    anchors.right: true
    margins.right: 20
    margins.bottom: root.bottomInset
    onSideChanged: Qt.callLater(root.place)
    Component.onCompleted: place()
    function place() {
        const left = root.side === "left"
        if (left) {
            root.anchors.left = true
            root.margins.left = 20
            root.margins.right = 0
            root.anchors.right = false
        } else {
            root.anchors.right = true
            root.margins.right = 20
            root.margins.left = 0
            root.anchors.left = false
        }
    }
    implicitWidth: illustrationWidth
    implicitHeight: illustrationHeight + bubbleSpace
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    // Весь ввод проходит сквозь окно, кроме эллипса головы и кнопок напоминания в облаке.
    readonly property bool bubbleHit: companion.bubble.interactive
    mask: fullscreenGuard.blocked || (!reactToPointer && !bubbleHit) ? emptyMask : liveMask
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
        // qs ipc call naomi remind water — то же напоминание, что у таймера, без ожидания. eyes, move — так же.
        function remind(kind: string): bool { return companion.remind(kind) }
    }

    // Источники системных событий: CPU, niri, UPower, сеть, ввод, процессы обновления.
    NaomiSystemSources {
        controller: companion.controller
        enabled: root.systemLines && root.visible
    }

    Region { id: emptyMask }
    Region {
        id: liveMask
        Region {
            x: root.reactToPointer ? Math.round(headZone.x) : 0
            y: root.reactToPointer ? Math.round(headZone.y) : 0
            width: root.reactToPointer ? Math.max(0, Math.round(headZone.width)) : 0
            height: root.reactToPointer ? Math.max(0, Math.round(headZone.height)) : 0
            shape: RegionShape.Ellipse
        }
        Region {
            x: root.bubbleHit ? Math.round(companion.bubble.x) : 0
            y: root.bubbleHit ? Math.round(companion.bubble.y) : 0
            width: root.bubbleHit ? Math.max(0, Math.round(companion.bubble.width)) : 0
            height: root.bubbleHit ? Math.max(0, Math.round(companion.bubble.height)) : 0
        }
    }
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
        active: root.visible
        opacity: fullscreenGuard.reveal
        animationsEnabled: root.animationsEnabled
        reactToPointer: root.reactToPointer
        systemLines: root.systemLines
        followPointer: false
        illustrationWidth: root.illustrationWidth
        illustrationHeight: root.illustrationHeight
    }
}
