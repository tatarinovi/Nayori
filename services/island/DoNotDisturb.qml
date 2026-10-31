import QtQuick
import "NotificationPolicy.js" as Policy

// Часы режима «Не беспокоить». until — абсолютное время окончания в миллисекундах.
// Прошедшее время означает, что режим уже завершён, в том числе после перезапуска.
QtObject {
    id: root
    property bool manual: false
    property double until: 0
    property double now: Date.now()
    readonly property bool active: Policy.dndActive(manual, until, now)
    readonly property string label: Policy.untilLabel(until, now)

    property Timer clock: Timer {
        interval: Math.max(50, Math.min(1000, Math.max(1, root.until - root.now)))
        repeat: true
        running: !root.manual && root.until > root.now
        onTriggered: root.now = Date.now()
    }
}
