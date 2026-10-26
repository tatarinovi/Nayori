pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List

// Группа уведомлений одного приложения. Из одного уведомления — одна карточка с цветным значком.
// Из нескольких — шапка (значок, имя, число, время, шеврон); развёрнутая показывает последнее
// уведомление крупно и остальные строками.
Rectangle {
    id: root
    required property var tokens
    property var notifications: null
    // Группа из List.group(): key, appName, appIcon, count, unread, time, latest, rest, ids.
    property var group: ({ count: 0, latest: ({}), rest: [], ids: [] })
    property bool expanded: false
    property double now: Date.now()
    // Сигнал на пользовательское раскрытие: страница запоминает выбор и отмечает записи прочитанными.
    signal toggleRequested()
    readonly property bool single: group.count <= 1
    readonly property bool hovered: hover.hovered
    readonly property var head: ({ appName: group.appName, appIcon: group.appIcon, desktopEntry: group.desktopEntry })
    implicitHeight: single ? singleBody.implicitHeight + 24 : headerRow.height + bodyClip.height + (bodyClip.height > 0 ? 12 : 0)
    radius: tokens.radius.medium + 4
    color: Qt.alpha(tokens.color.surfaceAlt, 0.16)
    border.width: 1
    border.color: root.hovered && single ? Qt.alpha(tokens.color.accentSoft, 0.8) : Qt.alpha(tokens.color.border, 0.85)
    HoverHandler { id: hover }

    // Одиночное уведомление: вся карточка нажимается.
    MouseArea {
        anchors.fill: parent
        enabled: root.single
        visible: root.single
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        Accessible.role: Accessible.Button
        Accessible.name: (root.group.latest.summary || "") + ". " + (root.group.latest.body || "")
        onClicked: if (root.notifications) root.notifications.activate(root.group.latest.id)
    }

    // --- Одно уведомление ---
    RowLayout {
        id: singleBody
        visible: root.single
        x: 14; y: 12; width: parent.width - 28
        spacing: 12
        NotificationIcon {
            Layout.alignment: Qt.AlignTop
            tokens: root.tokens
            record: root.head
            size: 40
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3
            IslandLabel {
                tokens: root.tokens
                Layout.fillWidth: true
                text: root.group.appName
                font.family: root.tokens.type.display.family
                font.pixelSize: 18
                font.weight: Font.Medium
                maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            IslandLabel {
                tokens: root.tokens
                Layout.fillWidth: true
                visible: text !== ""
                text: root.group.latest.summary || ""
                font.pixelSize: 14
                font.weight: Font.DemiBold
                maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            IslandLabel {
                tokens: root.tokens
                Layout.fillWidth: true
                visible: text !== ""
                text: root.group.latest.body || ""
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                maximumLineCount: 2; elide: Text.ElideRight
            }
            NotificationActions {
                Layout.fillWidth: true
                Layout.topMargin: 4
                tokens: root.tokens
                notifications: root.notifications
                record: root.group.latest
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 2
            RowLayout {
                spacing: 4
                IslandLabel {
                    tokens: root.tokens
                    text: List.relativeTime(root.now, root.group.time)
                    color: root.tokens.color.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.NoWrap
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 20
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: root.tokens.color.accent
                        visible: !root.group.latest.read && !root.hovered
                    }
                    NotificationClose {
                        anchors.centerIn: parent
                        tokens: root.tokens
                        visible: root.hovered
                        onClicked: if (root.notifications) root.notifications.remove(root.group.latest.id)
                    }
                }
            }
            Glyph {
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 8
                Layout.topMargin: 6
                Layout.preferredWidth: 14; Layout.preferredHeight: 14
                name: "chevronRight"
                ink: root.tokens.color.textMuted
            }
        }
    }

    // --- Несколько уведомлений ---
    Item {
        id: headerRow
        visible: !root.single
        x: 0; y: 0; width: parent.width; height: 56
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            Accessible.role: Accessible.Button
            Accessible.name: root.group.appName + ", " + root.group.count + ", " + (root.expanded ? "свернуть" : "развернуть")
            onClicked: root.toggleRequested()
        }
        RowLayout {
            x: 14; y: 0; width: parent.width - 28; height: parent.height
            spacing: 12
            NotificationIcon {
                Layout.alignment: Qt.AlignVCenter
                tokens: root.tokens
                record: root.head
                size: 36
            }
            IslandLabel {
                tokens: root.tokens
                text: root.group.appName
                font.family: root.tokens.type.display.family
                font.pixelSize: 18
                font.weight: Font.Medium
                maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(80, parent.width * 0.5)
            }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.max(22, badge.implicitWidth + 12); Layout.preferredHeight: 22
                radius: 11
                color: root.group.unread > 0 ? Qt.alpha(root.tokens.color.accent, 0.22) : Qt.alpha(root.tokens.color.surface, 0.5)
                border.width: 1
                border.color: root.group.unread > 0 ? Qt.alpha(root.tokens.color.accent, 0.55) : Qt.alpha(root.tokens.color.border, 0.7)
                Accessible.name: root.group.unread > 0 ? root.group.unread + " непрочитанных" : ""
                IslandLabel {
                    id: badge
                    anchors.centerIn: parent
                    tokens: root.tokens
                    text: root.group.count
                    font.pixelSize: 12
                    wrapMode: Text.NoWrap
                }
            }
            Item { Layout.fillWidth: true }
            IslandLabel {
                tokens: root.tokens
                text: List.relativeTime(root.now, root.group.time)
                color: root.tokens.color.textMuted
                font.pixelSize: 12
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignVCenter
            }
            NotificationClose {
                objectName: "notificationGroupClose_" + root.group.key
                tokens: root.tokens
                Layout.alignment: Qt.AlignVCenter
                Accessible.name: "Убрать все уведомления: " + root.group.appName
                onClicked: if (root.notifications) root.notifications.removeGroup(root.group.key)
            }
            Glyph {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 16; Layout.preferredHeight: 16
                name: root.expanded ? "chevronUp" : "chevronDown"
                ink: root.tokens.color.textMuted
            }
        }
    }
    Item {
        id: bodyClip
        visible: !root.single
        x: 12; y: headerRow.height
        width: parent.width - 24
        height: root.expanded ? bodyColumn.implicitHeight : 0
        clip: true
        opacity: root.expanded ? 1 : 0
        Behavior on height { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.base; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] } }
        Behavior on opacity { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
        ColumnLayout {
            id: bodyColumn
            width: parent.width
            spacing: 6
            NotificationCard {
                Layout.fillWidth: true
                tokens: root.tokens
                notifications: root.notifications
                record: root.group.latest
                now: root.now
            }
            Repeater {
                model: root.group.rest
                delegate: NotificationRow {
                    required property var modelData
                    Layout.fillWidth: true
                    tokens: root.tokens
                    notifications: root.notifications
                    record: modelData
                    now: root.now
                }
            }
        }
    }
}
