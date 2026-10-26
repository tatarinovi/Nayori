pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List
import "../../services/island/NotificationSources.js" as Sources

FocusScope {
    id: root
    objectName: "notificationPage"
    required property var tokens
    property var notifications: null
    property string filterMode: "all"
    property var expandedGroups: ({})
    property double now: Date.now()
    readonly property var groups: List.group(List.filter(notifications ? notifications.records : [], filterMode, Sources.systemSources()))
    signal closeRequested()
    Keys.onEscapePressed: closeRequested()
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.now = Date.now() }
    function toggleGroup(group) {
        const next = Object.assign({}, expandedGroups)
        next[group.key] = !next[group.key]
        expandedGroups = next
        if (next[group.key] && notifications) notifications.markAllRead(group.ids)
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{key: "all", label: "Все"}, {key: "unread", label: "Непрочитанные"}, {key: "system", label: "Системные"}]
                delegate: IslandAction {
                    required property var modelData
                    tokens: root.tokens
                    text: modelData.label
                    checked: root.filterMode === modelData.key
                    Accessible.selected: checked
                    opacity: checked ? 1 : 0.6
                    onClicked: root.filterMode = modelData.key
                }
            }
            Item { Layout.fillWidth: true }
            IslandAction {
                tokens: root.tokens
                text: "Очистить всё"
                enabled: !!root.notifications && root.notifications.records.length > 0
                onClicked: root.notifications.clear()
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            IslandLabel {
                anchors.centerIn: parent
                tokens: root.tokens
                visible: root.groups.length === 0
                text: root.filterMode === "unread" ? "Нет непрочитанных уведомлений" : root.filterMode === "system" ? "Нет системных уведомлений" : "Уведомлений пока нет"
                color: root.tokens.color.textMuted
            }
            ListView {
                id: list
                objectName: "notificationList"
                anchors.fill: parent
                clip: true
                spacing: 10
                model: root.groups
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: NotificationGroup {
                    required property var modelData
                    objectName: "notificationGroup_" + modelData.key
                    width: list.width
                    tokens: root.tokens
                    notifications: root.notifications
                    group: modelData
                    expanded: !!root.expandedGroups[modelData.key]
                    now: root.now
                    onToggleRequested: root.toggleGroup(modelData)
                }
            }
        }
    }
}
