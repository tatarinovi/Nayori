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
    property bool showingHistory: false
    readonly property var groups: List.group(List.filter(notifications ? notifications.records : [], filterMode, Sources.systemSources()))
    signal closeRequested()
    Keys.onEscapePressed: function(event) {
        if (root.showingHistory) {
            if (historyPane.confirming) historyPane.confirming = false
            else root.showingHistory = false
            event.accepted = true
            return
        }
        root.closeRequested()
        event.accepted = true
    }
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
            visible: !root.showingHistory
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
            AbstractButton {
                id: historyButton
                objectName: "notificationHistoryButton"
                visible: !root.showingHistory
                implicitWidth: Math.max(36, historyButtonLabel.implicitWidth + 40)
                implicitHeight: 36
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: "История"
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.showingHistory = true
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: historyButton.down ? root.tokens.color.surface : historyButton.hovered ? root.tokens.color.surfaceAlt : Qt.alpha(root.tokens.color.background, 0.28)
                    border.width: historyButton.visualFocus ? 2 : 1
                    border.color: historyButton.visualFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.45)
                }
                contentItem: RowLayout {
                    spacing: 6
                    Item { Layout.preferredWidth: 8 }
                    Glyph {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        implicitWidth: 14
                        implicitHeight: 14
                        name: "list"
                        ink: historyButton.hovered ? root.tokens.color.text : root.tokens.color.textMuted
                    }
                    IslandLabel {
                        id: historyButtonLabel
                        tokens: root.tokens
                        text: "История"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.preferredWidth: 8 }
                }
            }
            IslandAction {
                visible: !root.showingHistory
                tokens: root.tokens
                text: "Очистить всё"
                enabled: !!root.notifications && root.notifications.records.length > 0
                onClicked: root.notifications.clear()
            }
        }
        NotificationHistory {
            id: historyPane
            Layout.fillWidth: true
            Layout.fillHeight: root.showingHistory
            visible: root.showingHistory
            tokens: root.tokens
            notifications: root.notifications
            now: root.now
            onBackRequested: root.showingHistory = false
        }
        Item {
            visible: !root.showingHistory
            Layout.fillWidth: true
            Layout.fillHeight: !root.showingHistory
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
