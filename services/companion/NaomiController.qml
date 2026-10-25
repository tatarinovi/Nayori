import QtQuick
import "NaomiBehavior.js" as Behavior
import "NaomiDialogue.js" as Dialogue
import "NaomiLines.js" as Lines

// «Мозг» Naomi: склеивает чистую логику поглаживания и реплик с QML.
// Вход: pointerMoved(x, y) из иллюстрации и pointerInside. Выход: pet, petLean, bubbleVisible, bubbleText.
// Из кода: say("текст") — показать облако; react("вид") — повод для реплики из набора NaomiLines.js.
QtObject {
    id: root
    // Окно показано. Пока нет, Naomi не говорит сама.
    property bool active: true
    // false — курсор не учитывается: ни позы, ни реплик на поглаживание.
    property bool reactToPointer: true
    property bool reducedMotion: false
    property bool pointerInside: false
    // Тики идут таймером. В тестах выключают и вызывают advance(dt) сами.
    property bool automatic: true
    // Поздороваться при появлении. Не раньше, чем через greetingDelay миллисекунд.
    property bool greet: true
    property int greetingDelay: 1600

    // Для вывода.
    property real pet: 0
    property real petLean: 0
    property bool petting: false
    property bool bubbleVisible: false
    property string bubbleText: ""

    signal spoke(string text)

    property var petState: Behavior.create()
    property var talkState: Dialogue.create(Lines.lines, Math.random)
    property double lastTick: Date.now()
    property bool greeted: false

    function hour() { return new Date().getHours() }
    function publish() {
        root.pet = petState.pet
        root.petLean = petState.lean
        root.petting = petState.petting
        root.bubbleVisible = Dialogue.visible(talkState)
        if (root.bubbleText !== talkState.text) root.bubbleText = talkState.text
    }
    function announce(text) {
        publish()
        if (text) root.spoke(text)
    }
    // Показать облако с этим текстом. holdSeconds <= 0 — по длине текста. Перебивает любую реплику.
    function say(text, holdSeconds) {
        const shown = Dialogue.say(talkState, text, holdSeconds || 0, Math.random)
        root.announce(shown)
        return shown !== ""
    }
    // Повод для реплики по набору NaomiLines.js: greeting, idle, petStart, petAgain, petLong, petEnd.
    function react(kind, duration) {
        const text = Dialogue.react(talkState, kind, Math.random, { hour: hour(), duration: duration || 0 })
        root.announce(text)
        return text !== null
    }
    function hideBubble() { Dialogue.hide(talkState); publish() }
    // Событие мыши в координатах сцены Naomi.
    function pointerMoved(x, y) { if (root.reactToPointer) Behavior.move(petState, x, y) }
    function pointerLeft() { Behavior.leave(petState) }

    function advance(dt) {
        const out = Behavior.step(petState, { enabled: root.reactToPointer, reduced: root.reducedMotion }, dt)
        let spoken = null
        const quiet = out.petting || root.pointerInside
        if (out.started) spoken = Dialogue.react(talkState, "petStart", Math.random, { hour: hour() })
        if (out.long) spoken = Dialogue.react(talkState, "petLong", Math.random, { hour: hour() }) || spoken
        if (out.ended) spoken = Dialogue.react(talkState, "petEnd", Math.random, { hour: hour(), duration: out.duration }) || spoken
        // Покойные реплики — только пока курсор не на голове.
        const idle = Dialogue.tick(talkState, dt, Math.random, { active: root.active, quiet: quiet, hour: hour() })
        root.announce(spoken || idle)
    }

    onPointerInsideChanged: if (!pointerInside) pointerLeft()
    onReactToPointerChanged: { if (!reactToPointer) pointerLeft(); advance(0) }
    onReducedMotionChanged: advance(0)
    onActiveChanged: {
        lastTick = Date.now()
        if (!active) { Behavior.leave(petState) }
        else if (greet && !greeted) greetTimer.restart()
    }

    property Timer greetTimer: Timer {
        interval: root.greetingDelay
        onTriggered: {
            if (!root.active || root.greeted) return
            root.greeted = true
            root.react("greeting")
        }
    }
    property Timer ticker: Timer {
        // Пока ничего не происходит, хватает редких тиков: нужны лишь таймеры реплик.
        interval: root.petting || root.pointerInside || root.pet > 0.002 ? 33 : 250
        repeat: true
        running: root.automatic && root.active
        onTriggered: {
            const now = Date.now()
            root.advance(Math.min(1, (now - root.lastTick) / 1000))
            root.lastTick = now
        }
    }
    Component.onCompleted: if (active && greet && !greeted) greetTimer.start()
}
