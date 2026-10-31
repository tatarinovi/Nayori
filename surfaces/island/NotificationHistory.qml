pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List

// История закрытых уведомлений: поиск, группы приложений, удаление.
// Кнопок действий нет: живого уведомления уже нет, после перезапуска нет и картинки.
FocusScope {
    id: root
    objectName: "notificationHistory"
    required property var tokens
    property var notifications: null
    property double now: Date.now()
    property bool confirming: false
    signal backRequested()
    readonly property string query: searchField.text
    readonly property var groups: {
        if (!root.notifications || root.notifications.revision < 0 || !root.notifications.searchHistory) return []
        return root.notifications.searchHistory(root.query)
    }
    readonly property int entryCount: root.notifications && root.notifications.history ? root.notifications.history.length : 0
    onVisibleChanged: if (visible && !confirming) searchField.forceActiveFocus()
    Keys.onEscapePressed: function(event) {
        if (root.confirming) root.confirming = false
        else root.backRequested()
        event.accepted = true
    }
    function commitClear() {
        confirming = false
        if (notifications && notifications.clearHistory) notifications.clearHistory()
    }

    component HistoryDelete: AbstractButton {
        id: control
        required property var tokens
        property string label: "Удалить уведомление"
        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: label
        background: Rectangle {
            radius: width / 2
            color: control.down ? control.tokens.color.surface : control.hovered ? control.tokens.color.surfaceAlt : "transparent"
            border.width: control.visualFocus ? 2 : 0
            border.color: control.tokens.color.accent
        }
        contentItem: Item {
            Glyph {
                anchors.centerIn: parent
                width: 14
                height: 14
                name: "trash"
                ink: control.hovered ? control.tokens.color.text : control.tokens.color.textMuted
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IslandAction {
                objectName: "notificationHistoryBack"
                tokens: root.tokens
                text: "К\u00a0уведомлениям"
                onClicked: root.backRequested()
            }
            Item { Layout.fillWidth: true }
            IslandAction {
                objectName: "notificationHistoryClear"
                tokens: root.tokens
                text: "Очистить историю"
                enabled: root.entryCount > 0 && !root.confirming
                onClicked: root.confirming = true
            }
        }
        TextField {
            id: searchField
            objectName: "notificationHistorySearch"
            Layout.fillWidth: true
            implicitHeight: 36
            placeholderText: "Приложение, заголовок или текст"
            Accessible.name: "Поиск"
            color: root.tokens.color.text
            placeholderTextColor: Qt.alpha(root.tokens.color.textMuted, 0.7)
            selectionColor: root.tokens.color.accent
            selectedTextColor: root.tokens.color.accentText
            font.family: root.tokens.type.body.family
            font.pixelSize: 13
            selectByMouse: true
            leftPadding: 10
            rightPadding: 10
            verticalAlignment: TextInput.AlignVCenter
            background: Rectangle {
                radius: root.tokens.radius.small
                color: Qt.alpha(root.tokens.color.background, 0.5)
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.6)
            }
            Keys.onEscapePressed: function(event) {
                if (root.confirming) root.confirming = false
                else root.backRequested()
                event.accepted = true
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 6
                visible: root.groups.length === 0
                IslandLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    tokens: root.tokens
                    text: root.query.trim() !== "" ? "Ничего не нашлось" : "История пуста"
                    color: root.tokens.color.textMuted
                }
                IslandLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: root.query.trim() === ""
                    tokens: root.tokens
                    text: "Сюда попадают закрытые уведомления"
                    color: root.tokens.color.textMuted
                }
            }
            ListView {
                id: historyList
                objectName: "notificationHistoryList"
                anchors.fill: parent
                visible: root.groups.length > 0
                clip: true
                spacing: 10
                model: root.groups
                boundsBehavior: Flickable.StopAtBounds
                Accessible.name: "История уведомлений"
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Column {
                    id: groupColumn
                    required property var modelData
                    width: historyList.width
                    spacing: 6
                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: root.tokens.radius.medium + 4
                        color: Qt.alpha(root.tokens.color.surfaceAlt, 0.16)
                        border.width: 1
                        border.color: Qt.alpha(root.tokens.color.border, 0.85)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            spacing: 12
                            NotificationIcon {
                                Layout.alignment: Qt.AlignVCenter
                                tokens: root.tokens
                                record: groupColumn.modelData
                                size: 32
                            }
                            IslandLabel {
                                tokens: root.tokens
                                text: groupColumn.modelData.appName
                                font.family: root.tokens.type.display.family
                                font.pixelSize: 18
                                font.weight: Font.Medium
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            IslandLabel {
                                tokens: root.tokens
                                text: groupColumn.modelData.count
                                color: root.tokens.color.textMuted
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignVCenter
                            }
                            HistoryDelete {
                                Layout.alignment: Qt.AlignVCenter
                                tokens: root.tokens
                                label: "Удалить уведомления: " + groupColumn.modelData.appName
                                onClicked: if (root.notifications && root.notifications.deleteHistoryGroup)
                                    root.notifications.deleteHistoryGroup(groupColumn.modelData.sourceKey || groupColumn.modelData.key)
                            }
                        }
                    }
                    Repeater {
                        model: groupColumn.modelData.items
                        delegate: Rectangle {
                            id: entry
                            required property var modelData
                            width: groupColumn.width
                            implicitHeight: Math.max(40, entryRow.implicitHeight + 12)
                            radius: root.tokens.radius.medium
                            color: Qt.alpha(root.tokens.color.background, 0.3)
                            border.width: 1
                            border.color: Qt.alpha(root.tokens.color.border, 0.6)
                            RowLayout {
                                id: entryRow
                                x: 12
                                y: 6
                                width: parent.width - 24
                                spacing: 12
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: root.tokens.color.accent
                                    visible: !entry.modelData.read
                                }
                                IslandLabel {
                                    tokens: root.tokens
                                    text: entry.modelData.summary || entry.modelData.appName || ""
                                    font.family: root.tokens.type.display.family
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.maximumWidth: Math.max(80, entryRow.width * 0.42)
                                }
                                IslandLabel {
                                    tokens: root.tokens
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: entry.modelData.body || ""
                                    color: root.tokens.color.textMuted
                                    font.pixelSize: 13
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                                IslandLabel {
                                    tokens: root.tokens
                                    text: List.relativeTime(root.now, entry.modelData.time)
                                    color: root.tokens.color.textMuted
                                    font.pixelSize: 12
                                    wrapMode: Text.NoWrap
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                HistoryDelete {
                                    Layout.alignment: Qt.AlignVCenter
                                    tokens: root.tokens
                                    label: "Удалить уведомление"
                                    onClicked: if (root.notifications && root.notifications.deleteHistory)
                                        root.notifications.deleteHistory([entry.modelData.id])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        objectName: "notificationHistoryConfirm"
        anchors.fill: parent
        visible: root.confirming
        z: 2
        color: Qt.alpha(root.tokens.color.background, 0.94)
        Accessible.role: Accessible.Dialog
        Accessible.name: "Удалить всю историю?"
        Accessible.description: "Восстановить эти уведомления не получится"
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 420)
            spacing: 10
            IslandLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                tokens: root.tokens
                text: "Удалить всю историю?"
                font.family: root.tokens.type.display.family
                font.pixelSize: 18
                font.weight: Font.Medium
            }
            IslandLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                tokens: root.tokens
                text: "Восстановить эти уведомления не получится"
                color: root.tokens.color.textMuted
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                IslandAction {
                    id: cancelAction
                    objectName: "notificationHistoryCancel"
                    tokens: root.tokens
                    text: "Отмена"
                    onClicked: root.confirming = false
                }
                IslandAction {
                    objectName: "notificationHistoryDeleteAll"
                    tokens: root.tokens
                    text: "Да, удалить"
                    onClicked: root.commitClear()
                }
            }
        }
        onVisibleChanged: if (visible) cancelAction.forceActiveFocus()
    }
}
