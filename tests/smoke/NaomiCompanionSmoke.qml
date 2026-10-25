pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/companion"
import "surfaces/companion"

// Сцена Naomi целиком: наведение (HoverHandler), поглаживание, облако, настройки реакции.
// Время ведём вручную: controller.automatic = false, шаги — advance().
ShellRoot {
    FloatingWindow {
        id: scene
        visible: true
        implicitWidth: 300
        implicitHeight: 690
        Tokens { id: theme }
        NaomiCompanion {
            id: naomi
            tokens: theme
            x: 10
            y: 10
            width: 280
            height: 534 + 128
            greet: false
        }
        Timer { interval: 500; running: true; onTriggered: tests.test_all() }
        TestCase {
            id: tests
            name: "NaomiCompanion"
            when: false
            property var spoken: []

            function ok(cond, msg) {
                if (!cond) console.log("NAOMI_FAIL " + msg)
                verify(cond, msg)
            }
            // Шаги времени по 0,1 с: один advance ограничен секундой, как и реальный тик.
            function settle(seconds) {
                for (let t = 0; t < seconds; t += 0.1) naomi.controller.advance(0.1)
            }
            function until(check, msg) {
                for (let i = 0; i < 60 && !check(); i++) wait(50)
                if (!check()) console.log("NAOMI_FAIL timeout: " + msg + " opacity=" + naomi.bubble.opacity + " pop=" + naomi.bubble.pop + " shown=" + naomi.bubble.shown + " vis=" + naomi.controller.bubbleVisible + " text=" + naomi.controller.bubbleText)
                ok(check(), msg)
            }
            function head() {
                const r = naomi.headRect
                return { x: r.x + r.width / 2, y: r.y + r.height * 0.45, w: r.width }
            }
            // Водит курсором туда-сюда над головой, шагая время. Возвращает, было ли поглаживание.
            function stroke(seconds) {
                const h = head()
                let started = false
                const frames = Math.round(seconds * 60)
                for (let i = 0; i < frames; i++) {
                    const phase = i * 0.45
                    mouseMove(naomi, h.x + 0.33 * h.w * Math.sin(phase), h.y + 6 * Math.sin(phase * 0.6))
                    naomi.controller.advance(1 / 60)
                    if (naomi.controller.petting) started = true
                }
                return started
            }
            function reset() {
                naomi.reactToPointer = true
                naomi.systemLines = false
                naomi.controller.automatic = false
                mouseMove(naomi, 5, 5)
                settle(12)
            }
            function step_geometry() {
                ok(naomi.illustration.width === 280 && naomi.illustration.height === 534)
                compare(naomi.illustration.x, 0)
                compare(naomi.illustration.y, 128)
                compare(naomi.bubbleSpace, 128)
                const r = naomi.headRect
                ok(r.width > 90 && r.width < 140, "head zone width " + r.width)
                ok(r.x > 0 && r.x + r.width < naomi.width, "head inside illustration")
                ok(r.y >= naomi.bubbleSpace && r.y + r.height < naomi.bubbleSpace + naomi.illustration.height / 2, "head in the upper part")
                // Голова — малая доля площади окна: это и есть область, перехватывающая клики.
                ok(r.width * r.height < 0.12 * naomi.width * naomi.height, "head zone is small")
            }
            function step_pointer_over_head_and_petting() {
                const h = head()
                mouseMove(naomi, h.x, h.y)
                ok(naomi.illustration.pointerInside, "hover reaches the illustration")
                compare(naomi.controller.petting, false)
                ok(stroke(2.5), "stroking over the head starts petting")
                ok(naomi.controller.pet > 0.5, "pose on: " + naomi.controller.pet)
                compare(naomi.illustration.pet, naomi.controller.pet)
                ok(naomi.controller.bubbleVisible, "petting line shown")
                ok(naomi.controller.bubbleText.length > 0)
                // Поза и поворот головы без ошибок рендера: дальше сцена жива.
                naomi.illustration.grabToImage(function (r) {})
                // Курсор ушёл: жест заканчивается, поза плавно гаснет.
                mouseMove(naomi, 5, 5)
                naomi.controller.advance(0.3)
                ok(naomi.controller.pet > 0.05, "return is gradual")
                settle(8)
                compare(naomi.controller.petting, false)
                ok(naomi.controller.pet < 0.01, "pose returned: " + naomi.controller.pet)
            }
            function step_no_pet_over_body_or_when_disabled() {
                const h = head()
                for (let i = 0; i < 300; i++) {
                    mouseMove(naomi, naomi.illustration.x + 140 + 60 * Math.sin(i * 0.5), naomi.illustration.y + 340)
                    naomi.controller.advance(1 / 60)
                }
                compare(naomi.controller.petting, false)
                naomi.reactToPointer = false
                naomi.controller.advance(0.1)
                compare(stroke(2.5), false)
                compare(naomi.controller.pet, 0)
                naomi.reactToPointer = true
            }
            function inside(b) {
                return b.x >= 0 && b.y >= 0 && b.x + b.width <= naomi.width && b.y + b.height + b.tailLength <= naomi.height
            }
            function step_say_and_bubble_geometry() {
                compare(naomi.say("   ", 0), false)
                ok(naomi.say("Привет.", 0))
                naomi.controller.advance(0.01)
                until(function () { return naomi.bubble.visible }, "bubble visible")
                until(function () { return naomi.bubble.opacity > 0.95 }, "bubble fades in")
                const b = naomi.bubble
                ok(inside(b), "bubble inside the window: " + b.x + "," + b.y + " " + b.width + "x" + b.height)
                // Облако над головой, хвост смотрит вниз: кончик не ниже якоря у головы.
                ok(b.y + b.height + b.tailLength <= naomi.illustration.y + naomi.illustration.bubbleAnchor.y + 0.5, "bubble sits above the head")
                ok(b.y + b.height < naomi.headRect.y, "body of the cloud does not cover the head")
                // Размер по тексту: короткая реплика — компактное облачко без пустого места.
                compare(b.width, Math.ceil(b.textWidth + 2 * b.padX))
                ok(b.textWidth <= Math.ceil(b.contentWidth) + 4, "width follows the text: " + b.textWidth + " vs " + b.contentWidth)
                ok(b.width < 110 && b.height < 36, "short line is compact: " + b.width + "x" + b.height)
                ok(b.tailLength <= 12, "tail is small")
                const shortWidth = b.width, single = b.height
                // Реплика средней длины остаётся в одну строку, пока влезает.
                ok(naomi.say("Ой… приятно.", 0))
                ok(Math.abs(b.height - single) < 1 && b.width > shortWidth, "medium line stays on one row: " + b.width + "x" + b.height)
                // Длинный текст переносится и ограничен по ширине, не выходит за окно.
                ok(naomi.say("Это очень длинная реплика, которая обязана перенестись на несколько строк и не выйти за границы окна.", 0))
                ok(b.width <= 250 && b.width > 150, "width capped: " + b.width)
                ok(b.height > single * 1.8, "wrapped: " + b.height + " vs " + single)
                ok(inside(b), "long bubble inside: " + b.x + "," + b.y + " " + b.width + "x" + b.height)
                ok(naomi.bubble.shown, "long reply fits above the head")
                // Совсем длинный текст обрезается многоточием по числу строк, облако всё равно помещается.
                ok(naomi.say("слово ".repeat(120), 0))
                ok(inside(b) && b.shown, "huge text still fits: " + b.height)
                ok(b.height <= 5 * 24 + 2 * b.padY, "line limit: " + b.height)
                // Облако само не принимает ввод: у него нет обработчиков указателя.
                compare(naomi.bubble.enabled, true)
                naomi.controller.hideBubble()
                until(function () { return naomi.bubble.opacity < 0.05 }, "bubble fades out")
                until(function () { return !naomi.bubble.visible }, "bubble hides after fade")
            }
            function step_greeting_on_appearance() {
                // При появлении Naomi здоровается сама, с задержкой, и только один раз.
                ok(!naomi.controller.bubbleVisible, "quiet before greeting")
                naomi.controller.greeted = false
                naomi.controller.greetTimer.restart()
                wait(naomi.controller.greetingDelay + 300)
                ok(naomi.controller.bubbleVisible && naomi.controller.greeted, "greeting shown")
                naomi.controller.hideBubble()
                naomi.controller.greetTimer.restart()
                wait(naomi.controller.greetingDelay + 300)
                ok(!naomi.controller.bubbleVisible, "greeting is not repeated")
            }
            function step_spoke_signal() {
                spoken = []
                naomi.spoke.connect(function (text) { tests.spoken.push(text) })
                naomi.say("Сигнал.", 2)
                compare(spoken.length, 1)
                compare(spoken[0], "Сигнал.")
            }
            function step_reduced_motion_instant() {
                theme.animationsEnabled = false
                naomi.controller.advance(0)
                ok(stroke(2.5), "petting works without animations")
                ok(Math.abs(naomi.controller.pet - naomi.controller.petState.intensity) < 1e-9, "no easing without animations")
                ok(naomi.say("Без анимаций.", 0))
                compare(naomi.bubble.opacity, 1)
                mouseMove(naomi, 5, 5)
                settle(8)
                compare(naomi.controller.pet, 0)
                theme.animationsEnabled = true
            }
            function step_hover_not_over_other_regions_when_idle() {
                // Наведение не запускает реплик само: покойные реплики не раньше нескольких минут.
                naomi.controller.hideBubble()
                settle(2)
                const h = head()
                mouseMove(naomi, h.x, h.y)
                for (let i = 0; i < 60 * 30; i++) naomi.controller.advance(1 / 60)
                compare(naomi.controller.bubbleVisible, false)
            }
            // Системные реплики: ручной вызов, события, настройка, скрытая Naomi, поглаживание.
            function step_system_lines() {
                naomi.controller.systemState.nightKey = naomi.controller.dayKey()
                naomi.systemLines = true
                naomi.controller.hideBubble()
                settle(5)
                compare(naomi.trigger("nope"), false)
                const kinds = naomi.controller.triggerKinds()
                compare(kinds.length, 10)
                for (const kind of kinds) {
                    ok(naomi.trigger(kind), "manual trigger " + kind)
                    ok(naomi.controller.bubbleVisible && naomi.controller.bubbleText.length > 20, "line for " + kind)
                    naomi.controller.hideBubble()
                    settle(3)
                }
                ok(naomi.trigger("battery", 5) && naomi.controller.bubbleText.indexOf("У нас осталось 5% заряда.") === 0, "battery percent: " + naomi.controller.bubbleText)
                ok(naomi.trigger("night", 2) && naomi.controller.bubbleText.indexOf("Уже два часа ночи.") === 0, "night hour: " + naomi.controller.bubbleText)
                naomi.controller.hideBubble()
                settle(3)

                // Событие: низкий заряд приходит как реплика через очередь и облако.
                naomi.controller.systemBattery(false, 3, false)
                settle(30)
                compare(naomi.controller.bubbleVisible, false)
                naomi.controller.systemBattery(true, 15, false)
                settle(2)
                ok(naomi.controller.bubbleVisible, "battery event spoke")
                ok(naomi.controller.bubbleText.indexOf("У нас осталось 15% заряда.") === 0, naomi.controller.bubbleText)
                // Поглаживание не перебивает системную реплику.
                const shownText = naomi.controller.bubbleText
                ok(!naomi.controller.react("petEnd", 5), "petting does not interrupt a system line")
                compare(naomi.controller.bubbleText, shownText)
                naomi.controller.hideBubble()
                settle(60)

                // Во время поглаживания системная реплика ждёт.
                naomi.controller.systemNetwork("online")
                settle(2)
                naomi.controller.systemNetwork("offline")
                const h = head()
                mouseMove(naomi, h.x, h.y)
                settle(12)
                compare(naomi.controller.bubbleVisible, false)
                mouseMove(naomi, 5, 5)
                settle(2)
                ok(naomi.controller.bubbleVisible && naomi.controller.bubbleText.indexOf("Интернет пропал.") === 0, "line waited for the petting to end")
                naomi.controller.hideBubble()
                settle(60)
                naomi.controller.systemNetwork("online")

                // Настройка выключена и Naomi скрыта: событие не говорит и не копится.
                naomi.systemLines = false
                naomi.controller.systemIdle("away", true)
                naomi.controller.systemIdle("away", false)
                settle(60)
                compare(naomi.controller.bubbleVisible, false)
                naomi.systemLines = true
                settle(60)
                compare(naomi.controller.bubbleVisible, false)
                naomi.active = false
                naomi.controller.systemIdle("away", true)
                naomi.controller.systemIdle("away", false)
                settle(60)
                compare(naomi.controller.bubbleVisible, false)
                naomi.active = true
                settle(60)
                compare(naomi.controller.bubbleVisible, false)
                // Те же события при включённой настройке говорят.
                naomi.controller.systemIdle("away", true)
                naomi.controller.systemIdle("away", false)
                settle(2)
                ok(naomi.controller.bubbleVisible && naomi.controller.bubbleText.indexOf("О, ты вернулся.") === 0, "return line")
                naomi.controller.hideBubble()
                settle(5)
            }
            // Самые длинные реплики помещаются в облако на пять строк и не обрезаются.
            function step_system_lines_fit_bubble() {
                const b = naomi.bubble
                for (const kind of ["windows", "night", "game", "offline", "update", "cpu", "battery"]) {
                    naomi.controller.hideBubble()
                    settle(3)
                    ok(naomi.trigger(kind), "trigger " + kind)
                    until(function () { return b.opacity > 0.95 }, "bubble fades in for " + kind)
                    ok(b.shown && inside(b), kind + " inside the window: " + b.y + " " + b.width + "x" + b.height)
                    ok(b.height <= 5 * 24 + 2 * b.padY, kind + " within five lines: " + b.height)
                    ok(naomi.controller.bubbleText.length <= 100)
                    ok(b.contentWidth <= b.textWidth + 1, kind + " not truncated horizontally")
                    ok(!b.truncated, kind + " is not elided")
                }
                naomi.controller.hideBubble()
            }
            function test_all() {
                for (const step of [step_geometry, step_pointer_over_head_and_petting, step_no_pet_over_body_or_when_disabled,
                                    step_say_and_bubble_geometry, step_greeting_on_appearance, step_spoke_signal, step_reduced_motion_instant,
                                    step_hover_not_over_other_regions_when_idle, step_system_lines, step_system_lines_fit_bubble]) {
                    console.log("NAOMI step " + step.name)
                    reset()
                    step()
                }
                console.log("NAOMI_COMPANION_PASS")
                Qt.quit()
            }
        }
    }
}
