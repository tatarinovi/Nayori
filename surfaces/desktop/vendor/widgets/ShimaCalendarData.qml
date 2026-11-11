// Modified for Nayori, 2026-11-11: original calendar geometry with instance state.
import QtQuick
QtObject {
    id: root
    required property var hostBridge
    property int monthShift: 0
    readonly property var today: hostBridge.dateTime.clock.date
    readonly property int weekStart: Number(hostBridge.options.weekStart === undefined ? Qt.locale().firstDayOfWeek % 7 : hostBridge.options.weekStart)
    readonly property var viewingDate: new Date(today.getFullYear(), today.getMonth() + monthShift, 1)
    readonly property var weeks: getMonthMatrix(viewingDate)
    function getMonthMatrix(date): var {
        const year = date.getFullYear()
        const month = date.getMonth()
        const first = new Date(year, month, 1)
        const startOffset = (first.getDay() - root.weekStart + 7) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const daysInPrevMonth = new Date(year, month, 0).getDate()
        const cells = []

        for (let i = 0; i < startOffset; ++i) {
            cells.push({
                day: daysInPrevMonth - startOffset + i + 1,
                currentMonth: false,
                isToday: false
            })
        }
        for (let day = 1; day <= daysInMonth; ++day) {
            cells.push({
                day: day,
                currentMonth: true,
                isToday: year === root.today.getFullYear()
                    && month === root.today.getMonth()
                    && day === root.today.getDate()
            })
        }
        let nextDay = 1
        while (cells.length < 42)
            cells.push({ day: nextDay++, currentMonth: false, isToday: false })

        const rows = []
        for (let i = 0; i < cells.length; i += 7)
            rows.push(cells.slice(i, i + 7))
        return rows
    }
    function monthCells(): var {
        const cells = []
        for (const week of root.weeks) {
            for (const cell of week)
                cells.push(cell)
        }
        return cells
    }
}
