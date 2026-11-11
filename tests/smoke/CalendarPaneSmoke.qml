import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"

ShellRoot {
    id: testRoot
    Tokens { id: theme; animationsEnabled: false }
    QtObject {
        id: calendarService
        property var events: [{title: "Очень длинное название события для проверки переноса текста в узкой колонке", start: "2026-11-09T10:00:00+03:00", end: "2026-11-09T11:00:00+03:00", allDay: false, link: "https://example.com/meeting"}, {title: "Весь день", start: "2026-11-09", end: "2026-11-10", allDay: true}]
        property bool busy: false
        property string error: ""
        function refresh() {}
    }
    FloatingWindow {
        visible: true; implicitWidth: 278; implicitHeight: 340
        CalendarPane { id: pane; anchors.fill: parent; tokens: theme; service: calendarService; now: new Date("2026-11-09T10:30:00+03:00") }
    }
    function findItem(parent, name) {
        if (parent.objectName === name) return parent
        for (let child of parent.children || []) {
            const found = findItem(child, name)
            if (found) return found
        }
        return null
    }
    function checkEvent(past, actionable, current) {
        const entry = findItem(pane, "calendarEventCard0")
        const card = entry && findItem(entry, "calendarEventSurface")
        if (!card || entry.past !== past || entry.opacity !== (past ? 0.45 : 1)) throw new Error("event appearance")
        if (entry.current !== current) throw new Error("current event state")
        if (card.actionable !== actionable || card.enabled !== actionable || card.hoverEnabled !== actionable) throw new Error("event interaction")
        if (card.focusPolicy !== (actionable ? Qt.StrongFocus : Qt.NoFocus)) throw new Error("event keyboard focus")
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            if (pane.monthTitle !== "Ноябрь") throw new Error("standalone month: " + pane.monthTitle)
            if (pane.width !== 278 || pane.details) throw new Error("initial month")
            const dotIndex = (pane.month.getDay() + 6) % 7 + 8
            const dots = testRoot.findItem(pane, "calendarEventDots" + dotIndex)
            if (!dots || !dots.visible || dots.opacity !== 1) throw new Error("today dots")
            pane.now = new Date(2026, 10, 8, 12)
            if (dots.opacity !== 1) throw new Error("future dots")
            pane.now = new Date(2026, 10, 10)
            if (dots.opacity !== 0.45 || !dots.visible) throw new Error("past dots at midnight")
            pane.now = new Date("2026-11-09T10:30:00+03:00")
            if (dots.opacity !== 1) throw new Error("restored today dots")
            pane.openDay(new Date(2026, 10, 9))
            if (!pane.details || pane.selectedEvents.length !== 2 || pane.position !== 1) throw new Error("open agenda")
            // Instantiate delegates before checking the real card, including its disabled state.
            testRoot.findItem(pane, "calendarAgenda").forceLayout()
            testRoot.checkEvent(false, true, true)
            const card = testRoot.findItem(testRoot.findItem(pane, "calendarEventCard0"), "calendarEventSurface")
            const currentBackground = card.background.color.toString()
            pane.now = new Date("2026-11-09T10:00:00+03:00")
            testRoot.checkEvent(false, true, true)
            pane.now = new Date("2026-11-09T11:00:00+03:00")
            testRoot.checkEvent(true, false, false)
            pane.now = new Date("2026-11-09T09:00:00+03:00")
            testRoot.checkEvent(false, true, false)
            if (card.background.color.toString() === currentBackground) throw new Error("current tint not cleared")
            if (!Qt.colorEqual(card.background.border.color, Qt.alpha(theme.color.border, 0.16))) throw new Error("quiet border")
            if (pane.isCurrent(calendarService.events[1])) throw new Error("all day highlighted")
            if (pane.isCurrent({start: "invalid", end: "invalid", allDay: false})) throw new Error("invalid current event")
            const status = testRoot.findItem(pane, "calendarSyncStatus")
            if (status.text !== "") throw new Error("persistent sync label")
            calendarService.busy = true
            if (status.text !== "Обновляем…") throw new Error("sync progress")
            calendarService.error = "offline"
            if (status.text !== "Не удалось обновить") throw new Error("sync failure")
            calendarService.busy = false
            calendarService.error = ""
            if (status.text !== "") throw new Error("sync status not cleared")
            if (pane.isPast(calendarService.events[1])) throw new Error("all day still active")
            pane.now = new Date(2026, 10, 10)
            if (!pane.isPast(calendarService.events[1])) throw new Error("all day ended")
            if (pane.isPast({end: "invalid", allDay: false})) throw new Error("invalid end")
            const back = testRoot.findItem(pane, "calendarBack")
            if (back.text !== "←" || back.Accessible.name !== "Вернуться к месяцу") throw new Error("back icon accessibility")
            if (!pane.back() || pane.position !== 0 || pane.back()) throw new Error("back")
            pane.openDay(new Date(2026, 10, 10))
            if (pane.selectedEvents.length) throw new Error("exclusive all day end")
            calendarService.events = []
            if (pane.selectedEvents.length) throw new Error("empty")
            console.log("CALENDAR_PANE_PASS")
            Qt.quit()
        }
    }
}
