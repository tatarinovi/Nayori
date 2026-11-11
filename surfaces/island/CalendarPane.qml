pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: root
    required property var tokens
    property var service: null
    property date now: new Date()
    property date month: new Date(now.getFullYear(), now.getMonth(), 1)
    property date selectedDate: new Date()
    property bool details: false
    property real position: details ? 1 : 0
    readonly property var locale: Qt.locale("ru_RU")
    readonly property string monthTitle: {
        const name = locale.standaloneMonthName(month.getMonth())
        return name.charAt(0).toUpperCase() + name.slice(1)
    }
    readonly property var selectedEvents: eventsOn(selectedDate)
    clip: true
    function eventsOn(date) {
        const start = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
        const end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
        return service ? service.events.filter(e => {
            const a = new Date(e.allDay ? e.start + "T00:00:00" : e.start).getTime()
            const b = new Date(e.allDay ? e.end + "T00:00:00" : e.end).getTime()
            return a < end && (b > start || (a === b && a >= start))
        }) : []
    }
    function isPast(event) {
        const end = new Date(event.allDay ? event.end + "T00:00:00" : event.end).getTime()
        return Number.isFinite(end) && end <= now.getTime()
    }
    function isCurrent(event) {
        if (event.allDay) return false
        const start = new Date(event.start).getTime()
        const end = new Date(event.end).getTime()
        return start <= now.getTime() && now.getTime() < end
    }
    function openDay(date) {
        selectedDate = date
        details = true
        backButton.forceActiveFocus(Qt.TabFocusReason)
    }
    function back() {
        if (!details) return false
        details = false
        const index = (month.getDay() + 6) % 7 + selectedDate.getDate() - 1
        const item = days.itemAt(index)
        if (item) item.forceActiveFocus(Qt.TabFocusReason)
        return true
    }
    function changeMonth(delta) { month = new Date(month.getFullYear(), month.getMonth() + delta, 1) }
    Behavior on position { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.base; easing.type: Easing.InOutCubic } }
    component Caption: IslandLabel { tokens: root.tokens; font.pixelSize: 12; color: root.tokens.color.textMuted }
    component Heading: IslandLabel { tokens: root.tokens; font.family: root.tokens.type.display.family; font.pixelSize: 26 }
    component Action: IslandAction { tokens: root.tokens }
    ColumnLayout {
        objectName: "calendarMonthPage"
        x: -root.position * root.width
        width: root.width; height: root.height
        enabled: !root.details
        visible: root.position < 1
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Caption { text: "КАЛЕНДАРЬ"; font.letterSpacing: 2; Layout.fillWidth: true }
            Caption { text: Qt.formatDate(root.month, "yyyy") }
        }
        RowLayout {
            Layout.fillWidth: true
            Heading { objectName: "calendarMonthTitle"; text: root.monthTitle; Layout.fillWidth: true }
            Action { text: "‹"; Accessible.name: "Предыдущий месяц"; onClicked: root.changeMonth(-1) }
            Action { text: "›"; Accessible.name: "Следующий месяц"; onClicked: root.changeMonth(1) }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.tokens.color.border, 0.4) }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            columns: 7; rowSpacing: 3; columnSpacing: 2
            Repeater {
                model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
                Caption { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            }
            Repeater {
                id: days
                model: 42
                delegate: AbstractButton {
                    id: day
                    required property int index
                    readonly property int number: index - ((root.month.getDay() + 6) % 7) + 1
                    readonly property bool inMonth: number > 0 && number <= new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate()
                    readonly property date date: new Date(root.month.getFullYear(), root.month.getMonth(), number)
                    readonly property bool today: inMonth && date.toDateString() === root.now.toDateString()
                    readonly property bool past: date.getTime() < new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()).getTime()
                    readonly property int eventCount: inMonth ? root.eventsOn(date).length : 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    implicitHeight: 30
                    enabled: inMonth
                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: inMonth
                    Accessible.name: root.locale.toString(date, "d MMMM") + ", событий: " + eventCount
                    onClicked: root.openDay(date)
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: day.today ? root.tokens.color.accent : day.inMonth && (day.hovered || day.visualFocus) ? Qt.alpha(root.tokens.color.accent, 0.16) : "transparent"
                        border.width: day.inMonth && day.visualFocus ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    contentItem: Item {
                        IslandLabel {
                            tokens: root.tokens
                            anchors.centerIn: parent
                            text: day.inMonth ? day.number : ""
                            font.pixelSize: 14
                            color: day.today ? root.tokens.color.accentText : root.tokens.color.text
                        }
                        Flow {
                            objectName: "calendarEventDots" + day.index
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: Math.max(0, Math.min(parent.width, day.eventCount * 6 - 2))
                            height: childrenRect.height
                            spacing: 2
                            visible: day.eventCount > 0
                            opacity: day.past ? 0.45 : 1
                            Repeater {
                                model: day.eventCount
                                Rectangle {
                                    width: 4; height: 4; radius: 2
                                    color: day.today ? root.tokens.color.accentText : root.tokens.color.secondary
                                }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Caption { text: root.locale.toString(root.now, "d MMMM, dddd"); Layout.fillWidth: true; elide: Text.ElideRight }
        }
    }
    ColumnLayout {
        objectName: "calendarAgendaPage"
        x: (1 - root.position) * root.width
        width: root.width; height: root.height
        visible: root.position > 0
        enabled: root.details
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Action {
                id: backButton
                objectName: "calendarBack"
                text: "←"
                implicitWidth: 36
                Accessible.name: "Вернуться к месяцу"
                onClicked: root.back()
                contentItem: IslandLabel {
                    tokens: root.tokens
                    text: backButton.text
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Heading { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: root.locale.toString(root.selectedDate, "d MMMM"); font.pixelSize: 20 }
        }
        Caption { text: root.locale.toString(root.selectedDate, "dddd") + " · событий: " + root.selectedEvents.length }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.tokens.color.border, 0.4) }
        ListView {
            id: agenda
            objectName: "calendarAgenda"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 0
            model: root.selectedEvents
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool past: root.isPast(modelData)
                readonly property bool current: root.isCurrent(modelData)
                opacity: past ? 0.45 : 1
                objectName: "calendarEventCard" + index
                width: Math.max(0, agenda.width - 12)
                height: eventCard.implicitHeight + 8
                // Connected timeline spans the gaps between variable-height cards.
                Rectangle {
                    x: 3
                    y: entry.index === 0 ? 18 : 0
                    width: 1
                    height: Math.max(0, (entry.index === agenda.count - 1 ? 18 : entry.height) - y)
                    color: Qt.alpha(root.tokens.color.accent, 0.3)
                }
                Rectangle { x: 0; y: 15; width: 7; height: 7; radius: 4; color: root.tokens.color.accent }
                AbstractButton {
                    id: eventCard
                    objectName: "calendarEventSurface"
                    readonly property string link: entry.modelData.link || ""
                    readonly property bool actionable: !entry.past && /^https?:\/\//i.test(link)
                    x: 18
                    width: Math.max(0, entry.width - x)
                    implicitHeight: eventContent.implicitHeight + 16
                    height: implicitHeight
                    padding: 8
                    enabled: actionable
                    hoverEnabled: actionable
                    focusPolicy: actionable ? Qt.StrongFocus : Qt.NoFocus
                    Accessible.name: entry.modelData.title + (actionable ? ", открыть ссылку" : "")
                    onClicked: if (actionable) Qt.openUrlExternally(link)
                    background: IslandCard {
                        tokens: root.tokens
                        color: Qt.tint(Qt.alpha(root.tokens.color.surfaceAlt, eventCard.down && eventCard.actionable ? 0.65 : eventCard.hovered && eventCard.actionable ? 0.5 : 0.35), Qt.alpha(root.tokens.color.accent, entry.current ? 0.08 : 0))
                        border.width: 1
                        border.color: eventCard.visualFocus ? root.tokens.color.accent : entry.current ? Qt.alpha(root.tokens.color.accent, 0.32) : Qt.alpha(root.tokens.color.border, eventCard.hovered && eventCard.actionable ? 0.4 : 0.16)
                        Behavior on color { ColorAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
                    }
                    contentItem: ColumnLayout {
                        id: eventContent
                        spacing: 4
                        Caption {
                            Layout.fillWidth: true
                            text: entry.modelData.allDay ? "Весь день" : Qt.formatTime(new Date(entry.modelData.start), "HH:mm") + (entry.modelData.end !== entry.modelData.start ? " – " + Qt.formatTime(new Date(entry.modelData.end), "HH:mm") : "")
                        }
                        IslandLabel {
                            objectName: "calendarEventTitle"
                            tokens: root.tokens
                            Layout.fillWidth: true
                            text: entry.modelData.title
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        cursorShape: eventCard.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
            Caption { anchors.fill: parent; visible: !agenda.count; wrapMode: Text.Wrap; text: root.service && root.service.busy ? "Обновляем…" : root.service && root.service.error ? root.service.error : "На этот день событий нет" }
        }
        RowLayout {
            Layout.fillWidth: true
            Caption { objectName: "calendarSyncStatus"; Layout.fillWidth: true; text: root.service && root.service.error ? "Не удалось обновить" : root.service && root.service.busy ? "Обновляем…" : ""; elide: Text.ElideRight }
            Action { text: "↻"; Accessible.name: "Обновить календарь"; enabled: !!root.service && !root.service.busy; onClicked: root.service.refresh() }
        }
    }
}
