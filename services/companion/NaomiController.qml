import QtQuick
import "NaomiBehavior.js" as Behavior
import "NaomiDialogue.js" as Dialogue
import "NaomiLines.js" as Lines
import "NaomiSystemData.js" as SystemData
import "NaomiSystemEvents.js" as SystemEvents
import "NaomiReminders.js" as Reminders
import "NaomiSession.js" as Session
import "NaomiInteractionEvents.js" as Interaction

// «Мозг» Naomi: склеивает чистую логику поглаживания и реплик с QML.
// Вход: pointerMoved(x, y) из иллюстрации и pointerInside. Выход: pet, petLean, bubbleVisible, bubbleText.
// Из кода: say("текст") — показать облако; react("вид") — повод для реплики из набора NaomiLines.js.
// Системные события (CPU, окна, батарея, сеть, ввод, обновление) приходят в systemWindows/systemBattery/
// systemNetwork/systemUpdate/systemIdle и cpuLoad; решает и показывает NaomiSystemEvents.js.
QtObject {
    id: root
    // Окно показано. Пока нет, Naomi не говорит сама.
    property bool active: true
    // false — курсор не учитывается: ни позы, ни реплик на поглаживание.
    property bool reactToPointer: true
    property bool reducedMotion: false
    // Комментировать системные события. false — ни реплик, ни очереди. Приветствие и поглаживание не зависят.
    property bool systemLines: true
    // Нагрузка CPU 0..1 (раз в секунду, из surfaces/island/Cpu.qml) и «пользователь не двигал мышь минуту».
    property real cpuLoad: 0
    property bool userIdle: false
    property bool reminderPresent: true
    property bool reminderTracking: true
    property var reminderIntervals: ({ water: 60, eyes: 20, move: 60 })
    onReminderIntervalsChanged: Reminders.configure(remindState, reminderIntervals)
    property bool optionalQuiet: false
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
    // Кнопки «позже» и «окей» в облаке напоминания.
    property bool bubbleActions: false

    signal spoke(string text)

    property var interactionState: Interaction.create()
    property var petState: Behavior.create()
    property var talkState: Dialogue.create(Lines.lines, Math.random)
    property var systemState: SystemEvents.create(SystemData.data, Lines.lines)
    property var remindState: Reminders.create(Lines.lines)
    property double lastTick: Date.now()
    property bool greeted: false

    function hour() { return new Date().getHours() }
    function dayKey() {
        const d = new Date()
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
    }
    function publish() {
        root.pet = petState.pet
        root.petLean = petState.lean
        root.petting = petState.petting
        const critical = talkState.kind === "critical" && Dialogue.visible(talkState)
        const rem = critical ? null : Reminders.view(remindState)
        root.bubbleActions = !!(rem && rem.actions)
        if (rem) {
            root.bubbleVisible = true
            if (root.bubbleText !== rem.text) root.bubbleText = rem.text
        } else {
            root.bubbleVisible = Dialogue.visible(talkState)
            if (root.bubbleText !== talkState.text) root.bubbleText = talkState.text
        }
    }
    function announce(text) {
        publish()
        if (text) root.spoke(text)
    }
    // Показать облако с этим текстом. holdSeconds <= 0 — по длине текста. Перебивает любую реплику.
    function say(text, holdSeconds) {
        if (Reminders.blocking(remindState)) return false
        const shown = Dialogue.say(talkState, text, holdSeconds || 0, Math.random)
        root.announce(shown)
        return shown !== ""
    }
    // Повод для реплики по набору NaomiLines.js: greeting, idle, petStart, petAgain, petLong, petEnd.
    function react(kind, duration) {
        if (Reminders.blocking(remindState) || (kind === "greeting" && (root.optionalQuiet || !Session.canGreet(Date.now())))) return false
        const text = Dialogue.react(talkState, kind, Math.random, { hour: hour(), duration: duration || 0 })
        if (text && kind === "greeting") Session.greeted(Date.now())
        root.announce(text)
        return text !== null
    }
    // Системные события от источников. Состояние запоминается всегда: так включение настройки
    // не принимает уже открытые окна за новые.
    function systemWindows(list, available) {
        root.optionalQuiet = !!(available && Array.isArray(list) && list.some(w => w.focused && SystemEvents.classify(SystemData.data, w.appId) === "game"))
        SystemEvents.windows(systemState, list, available)
    }
    function systemMusic(players) {
        const kind = Interaction.music(interactionState, players)
        systemState.musicPlaying = interactionState.musicPlaying
        if (kind) SystemEvents.offer(systemState, kind, {})
    }
    function systemBattery(present, percent, charging) {
        SystemEvents.battery(systemState, { present: present, percent: percent, charging: charging })
    }
    function systemNetwork(state) { SystemEvents.network(systemState, state) }
    function systemUpdate(running) { SystemEvents.update(systemState, running) }
    function systemIdle(level, isIdle) { SystemEvents.idle(systemState, level, isIdle) }
    function systemMediaPlayback(playing) { SystemEvents.mediaPlayback(systemState, playing) }
    // Разобрать вывод проверки процессов pacman/paru/yay/topgrade и db.lck; true — идёт обновление.
    function scanUpdate(text) { return SystemEvents.scanUpdate(text) }
    // Вручную показать системную реплику (qs ipc call naomi trigger cpu): всегда, поверх облака,
    // без кулдаунов и очереди. value — заряд для battery или час 0–5 для night. Неизвестный вид — false.
    function trigger(kind, value) {
        const text = SystemEvents.preview(systemState, kind, value, hour(), Math.random)
        if (text === "") return false
        const shown = Dialogue.system(talkState, text, Math.random)
        root.announce(shown)
        return shown !== ""
    }
    // Напоминание сразу (qs ipc call naomi remind water): та же очередь, что у таймера.
    // Срок в next не двигается. Отсчёт и занятое облако не перебиваются — просьба ждёт.
    function remind(kind) {
        if (!Reminders.accepts(kind)) return false
        const line = Reminders.request(remindState, kind, {
            cloud: Reminders.blocking(remindState) ? "busy" : Dialogue.slot(talkState),
            rnd: Math.random
        })
        publish()
        if (line) root.spoke(line)
        return true
    }
    // Поводы копятся только пока Naomi показана и настройка включена.
    function syncSystem() { SystemEvents.setOn(systemState, root.active && root.systemLines) }
    function triggerKinds() { return SystemEvents.kinds(systemState) }
    function hideBubble() { Dialogue.hide(talkState); Reminders.dismiss(remindState); publish() }
    // Кнопка в облаке напоминания: «ok» или «later».
    function reminderChoice(id) {
        const line = id === "ok" ? Reminders.okay(remindState, Math.random)
            : id === "later" ? Reminders.later(remindState) : ""
        publish()
        if (line) root.spoke(line)
    }
    // Событие мыши в координатах сцены Naomi.
    function pointerMoved(x, y) {
        if (root.reactToPointer) { Behavior.move(petState, x, y); Interaction.move(interactionState, x, y) }
    }
    function pointerLeft() {
        Behavior.leave(petState)
        Interaction.hover(interactionState, 0, { enabled: false, inside: false })
    }

    function advance(dt) {
        const out = Behavior.step(petState, { enabled: root.reactToPointer, reduced: root.reducedMotion }, dt)
        let spoken = null
        const pointerQuiet = out.petting || root.pointerInside
        systemState.pointerInside = root.pointerInside
        if (Interaction.hover(interactionState, dt, { enabled: root.active && root.reactToPointer, inside: root.pointerInside }) && !root.optionalQuiet) SystemEvents.offer(systemState, "hoverStill", {})
        if (!Reminders.blocking(remindState)) {
            if (out.started) spoken = Dialogue.react(talkState, "petStart", Math.random, { hour: hour() })
            if (out.long) spoken = Dialogue.react(talkState, "petLong", Math.random, { hour: hour() }) || spoken
            if (out.ended) spoken = Dialogue.react(talkState, "petEnd", Math.random, { hour: hour(), duration: out.duration }) || spoken
        }
        const blockedBefore = Reminders.blocking(remindState)
        if (blockedBefore) {
            if (!Dialogue.visible(talkState)) talkState.until = talkState.time
            Dialogue.armShared(talkState, "reminder")
        }
        const remLine = Reminders.tick(remindState, dt, {
            active: root.reminderTracking,
            present: root.reminderPresent,
            cloud: !root.active || blockedBefore || root.optionalQuiet || pointerQuiet || Dialogue.blocksShared(talkState, "reminder") ? "busy" : Dialogue.slot(talkState),
            rnd: Math.random
        })
        const blocked = Reminders.blocking(remindState)
        // Покойные реплики — только пока курсор не на голове и облако не занято напоминанием.
        const idle = Dialogue.tick(talkState, dt, Math.random, { active: root.active, quiet: pointerQuiet || blocked || root.optionalQuiet || systemState.queue.length > 0, hour: hour() })
        // Системные реплики — после остальных: облако уже занято, если Naomi только что заговорила.
        const due = SystemEvents.tick(systemState, dt, { enabled: root.systemLines, active: root.active, quiet: pointerQuiet, petting: out.petting, optionalQuiet: root.optionalQuiet,
            hour: hour(), dayKey: dayKey(), userIdle: root.userIdle, cpu: root.cpuLoad,
            cloud: blocked || Dialogue.blocksShared(talkState, "system") ? "busy" : Dialogue.slot(talkState),
            interactionCloud: blocked ? "busy" : Dialogue.slot(talkState, 2),
            criticalVisible: talkState.kind === "critical" && Dialogue.visible(talkState), rnd: Math.random })
        const system = due ? Dialogue.system(talkState, due.text, Math.random, due.priority >= 4) : null
        root.announce(system || spoken || (!blocked ? idle : null) || remLine)
    }

    onPointerInsideChanged: if (!pointerInside) pointerLeft()
    onReactToPointerChanged: { if (!reactToPointer) pointerLeft(); advance(0) }
    onReducedMotionChanged: advance(0)
    onSystemLinesChanged: syncSystem()
    onActiveChanged: {
        syncSystem()
        lastTick = Date.now()
        if (!active) { root.pointerLeft(); greetTimer.stop(); Dialogue.hide(talkState) }
        else if (greet && Session.canGreet(Date.now())) greetTimer.restart()
    }

    property Timer greetTimer: Timer {
        interval: root.greetingDelay
        onTriggered: {
            if (!root.active || !root.greet || !Session.canGreet(Date.now())) return
            root.greeted = root.react("greeting")
        }
    }
    property Timer ticker: Timer {
        // Пока ничего не происходит, хватает редких тиков: нужны лишь таймеры реплик.
        interval: root.petting || root.pointerInside || root.pet > 0.002 ? 33 : 250
        repeat: true
        running: root.automatic && (root.active || root.reminderTracking)
        onTriggered: {
            const now = Date.now()
            root.advance(Math.min(1, (now - root.lastTick) / 1000))
            root.lastTick = now
        }
    }
    Component.onCompleted: {
        syncSystem()
        Reminders.configure(remindState, reminderIntervals)
        if (active && greet && Session.canGreet(Date.now())) greetTimer.start()
    }
}
