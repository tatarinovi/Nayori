pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List

// Кнопки действий самого уведомления и поле быстрого ответа, если приложение их передало.
// «default» кнопки не получает: это нажатие на саму карточку.
ColumnLayout {
    id: root
    required property var tokens
    property var notifications: null
    property var record: ({})
    readonly property var actions: List.visibleActions(record)
    // live === false и запись с диска: исходного уведомления уже нет, кнопки и ответ недоступны.
    readonly property bool actionsLive: record.live !== false && record.loadedFromDisk !== true
    readonly property bool canReply: !!record.hasReply && !record.closed && actionsLive
    readonly property bool wanted: actionsLive && !record.closed && (actions.length > 0 || !!record.hasReply)
    property bool replying: false
    visible: wanted
    spacing: 6
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.actions
            delegate: IslandAction {
                required property var modelData
                tokens: root.tokens
                implicitHeight: 28
                text: modelData.text
                width: Math.min(implicitWidth, root.width)
                onClicked: if (root.notifications) root.notifications.invoke(root.record.id, modelData.id)
            }
        }
        IslandAction {
            visible: root.canReply
            tokens: root.tokens
            implicitHeight: 28
            text: "Ответить"
            checkable: true
            checked: root.replying
            onClicked: { root.replying = !root.replying; if (root.replying) field.forceActiveFocus() }
        }
    }
    RowLayout {
        visible: root.replying && root.canReply
        Layout.fillWidth: true
        spacing: 6
        TextField {
            id: field
            Layout.fillWidth: true
            implicitHeight: 32
            placeholderText: root.record.replyPlaceholder || "Ваш ответ"
            color: root.tokens.color.text
            placeholderTextColor: Qt.alpha(root.tokens.color.textMuted, 0.7)
            font.family: root.tokens.type.body.family
            font.pixelSize: 13
            selectByMouse: true
            leftPadding: 10; rightPadding: 10
            background: Rectangle {
                radius: root.tokens.radius.small
                color: Qt.alpha(root.tokens.color.background, 0.5)
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.6)
            }
            function send() {
                const text = field.text.trim()
                if (!text || !root.notifications) return
                root.notifications.reply(root.record.id, text)
                field.text = ""
                root.replying = false
            }
            onAccepted: send()
            Keys.onEscapePressed: function(event) { root.replying = false; event.accepted = true }
        }
        IslandAction {
            tokens: root.tokens
            implicitHeight: 32
            text: "Отправить"
            enabled: field.text.trim().length > 0
            onClicked: field.send()
        }
    }
}
