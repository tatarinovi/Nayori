import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"

ShellRoot {
    Tokens { id: theme; animationsEnabled: false }
    QtObject {
        id: service
        property var events: [{title: "Очень длинное название события для проверки переноса текста в узкой колонке", start: "2026-11-09T10:00:00+03:00", end: "2026-11-09T11:00:00+03:00", allDay: false}, {title: "Весь день", start: "2026-11-09", end: "2026-11-10", allDay: true}]
        property bool busy: false
        property string error: ""
        function refresh() {}
    }
    FloatingWindow {
        visible: true; implicitWidth: 278; implicitHeight: 340
        CalendarPane { id: pane; anchors.fill: parent; tokens: theme; service: service; now: new Date(2026, 10, 9) }
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            if (pane.monthTitle !== "Ноябрь") throw new Error("standalone month: " + pane.monthTitle)
            if (pane.width !== 278 || pane.details) throw new Error("initial month")
            pane.openDay(new Date(2026, 10, 9))
            if (!pane.details || pane.selectedEvents.length !== 2 || pane.position !== 1) throw new Error("open agenda")
            if (!pane.back() || pane.position !== 0 || pane.back()) throw new Error("back")
            pane.openDay(new Date(2026, 10, 10))
            if (pane.selectedEvents.length) throw new Error("exclusive all day end")
            service.events = []
            if (pane.selectedEvents.length) throw new Error("empty")
            console.log("CALENDAR_PANE_PASS")
            Qt.quit()
        }
    }
}
