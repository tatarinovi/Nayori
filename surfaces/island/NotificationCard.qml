pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List

// Крупная карточка последнего уведомления группы: картинка слева, текст, время и точка справа.
Rectangle {
    id: root
    required property var tokens
    property var notifications: null
    property var record: ({})
    property double now: Date.now()
    readonly property bool hovered: hover.hovered
    implicitHeight: content.implicitHeight + 24
    radius: tokens.radius.medium
    color: Qt.alpha(tokens.color.background, 0.38)
    border.width: 1
    border.color: root.hovered ? Qt.alpha(tokens.color.accentSoft, 0.8) : Qt.alpha(tokens.color.border, 0.8)
    HoverHandler { id: hover }
    // Нажатие на саму карточку: открыть приложение. Кнопки лежат выше и перехватывают своё.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        Accessible.role: Accessible.Button
        Accessible.name: (root.record.summary || "") + ". " + (root.record.body || "")
        onClicked: if (root.notifications) root.notifications.activate(root.record.id)
    }
    RowLayout {
        id: content
        x: 12; y: 12; width: parent.width - 24
        spacing: 12
        NotificationThumb {
            id: thumb
            Layout.alignment: Qt.AlignTop
            tokens: root.tokens
            record: root.record
            size: 52
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3
            IslandLabel {
                tokens: root.tokens
                Layout.fillWidth: true
                text: root.record.summary || root.record.appName || ""
                font.family: root.tokens.type.display.family
                font.pixelSize: 17
                font.weight: Font.Medium
                maximumLineCount: 1
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            IslandLabel {
                tokens: root.tokens
                Layout.fillWidth: true
                visible: text !== ""
                text: root.record.body || ""
                color: thumb.hasImage && thumb.wide ? root.tokens.color.textMuted : root.tokens.color.text
                font.pixelSize: 13
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            IslandLabel {
                tokens: root.tokens
                visible: thumb.caption !== ""
                text: thumb.caption
                color: root.tokens.color.textMuted
                font.pixelSize: 11
                wrapMode: Text.NoWrap
            }
            NotificationActions {
                Layout.fillWidth: true
                Layout.topMargin: 4
                tokens: root.tokens
                notifications: root.notifications
                record: root.record
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 4
            IslandLabel {
                tokens: root.tokens
                text: List.relativeTime(root.now, root.record.time)
                color: root.tokens.color.textMuted
                font.pixelSize: 12
                wrapMode: Text.NoWrap
                Layout.alignment: Qt.AlignVCenter
            }
            // Одна ячейка: точка «не прочитано», при наведении — кнопка «×».
            Item {
                Layout.preferredWidth: 28; Layout.preferredHeight: 20
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: root.tokens.color.accent
                    visible: !root.record.read && !root.hovered
                }
                NotificationClose {
                    anchors.centerIn: parent
                    width: 28; height: 28
                    tokens: root.tokens
                    visible: root.hovered
                    onClicked: if (root.notifications) root.notifications.remove(root.record.id)
                }
            }
        }
    }
}
