import QtQuick
import "../../services/companion"

// Naomi целиком: иллюстрация внизу, а над головой — облачко с репликой, хвостик вниз к голове.
// Склеивает иллюстрацию, NaomiController (поглаживание и реплики) и NaomiBubble.
// Используется окном рабочего стола и предпросмотром в настройках.
// Размер компонента = иллюстрация + место под облачко сверху (всё, что выше иллюстрации);
// иллюстрация прижата вниз и по центру. Облачко подгоняется под текст и не выходит за границы.
Item {
    id: root
    required property var tokens
    property string companionStyle: "current"
    property bool active: true
    property bool animationsEnabled: true
    // Реагировать на курсор: поза поглаживания и реплики на неё.
    property bool reactToPointer: true
    // Следить головой за курсором по всему компоненту (предпросмотр) или только над головой.
    property bool followPointer: false
    property bool greet: true
    // Комментировать системные события (CPU, окна, батарея, сеть, обновление). Предпросмотр в настройках — нет.
    property bool systemLines: false
    property real illustrationWidth: 280
    property real illustrationHeight: companionStyle === "pixel-art" ? 400 : 534

    // Место сверху под облачко: всё, что выше иллюстрации.
    readonly property real bubbleSpace: Math.max(0, height - illustrationHeight)
    // Эллипс головы в координатах компонента: окно оставляет вход только в нём.
    readonly property rect headRect: Qt.rect(art.x + art.headRect.x, art.y + art.headRect.y,
                                             art.headRect.width, art.headRect.height)
    readonly property alias controller: brain
    readonly property alias illustration: art
    readonly property alias bubble: cloud

    // Показать облако с репликой. holdSeconds <= 0 — по длине текста. Перебивает любую реплику.
    function say(text, holdSeconds) { return brain.say(text, holdSeconds) }
    // Повод для реплики из набора NaomiLines.js: greeting, idle, petStart, petAgain, petLong, petEnd.
    function react(kind) { return brain.react(kind) }
    // Показать системную реплику вручную: cpu, idle, terminal, game, battery, windows, night, update, offline, return.
    function trigger(kind, value) { return brain.trigger(kind, value) }
    // Напоминание сразу: water, eyes, move. Та же очередь, что у таймера, срок не сдвигается.
    function remind(kind) { return brain.remind(kind) }
    signal spoke(string text)

    NaomiController {
        id: brain
        active: root.active
        greet: root.greet
        systemLines: root.systemLines
        reactToPointer: root.reactToPointer
        reducedMotion: root.tokens.motion.off || !root.animationsEnabled
        pointerInside: art.pointerInside
        onSpoke: text => root.spoke(text)
    }

    NaomiArtwork {
        id: art
        style: root.companionStyle
        tokens: root.tokens
        x: (root.width - width) / 2
        y: root.height - height
        width: root.illustrationWidth
        height: root.illustrationHeight
        active: root.active
        animationsEnabled: root.animationsEnabled
        followPointer: root.followPointer
        pointerTracking: root.reactToPointer
        pet: brain.pet
        petLean: brain.petLean
        // Пока облако на экране — в том числе напоминание и отсчёт — рот говорит тем же флагом.
        speaking: cloud.shown
        onPointerMoved: (x, y) => brain.pointerMoved(x, y)
    }

    // Облачко над головой: хвост смотрит вниз, к голове. Не принимает события мыши.
    NaomiBubble {
        id: cloud
        tokens: root.tokens
        animationsEnabled: root.animationsEnabled
        text: brain.bubbleText
        actionsOn: brain.bubbleActions
        onActionChosen: id => brain.reminderChoice(id)
        // Если над головой не хватает места под облачко, оно не показывается, а не обрезается.
        shown: brain.bubbleVisible && root.active && fits
        readonly property real anchorX: art.x + art.bubbleAnchor.x
        readonly property real anchorY: art.y + art.bubbleAnchor.y
        readonly property real margin: 4
        readonly property bool fits: height + tailLength + margin <= anchorY && root.width >= 80
        maxWidth: Math.max(80, Math.min(250, root.width - 2 * margin))
        // По горизонтали облачко центрируется над хвостом и сдвигается внутрь, но не выходит за край.
        x: Math.max(margin, Math.min(root.width - width - margin, anchorX - width / 2))
        y: anchorY - tailLength - height
        tailX: anchorX - x
    }
}
