pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../services/island/NotificationList.js" as List

// Компактная строка более старого уведомления группы: значок, заголовок, приглушённый текст, время.
Rectangle {
    id: root
    required property var tokens
    property var notifications: null
    property var record: ({})
    property double now: Date.now()
    readonly property bool hovered: hover.hovered
    implicitHeight: Math.max(40, content.implicitHeight + 12)
    radius: tokens.radius.medium
    color: root.hovered ? Qt.alpha(tokens.color.surfaceAlt, 0.4) : Qt.alpha(tokens.color.background, 0.3)
    border.width: 1
    border.color: root.hovered ? Qt.alpha(tokens.color.accentSoft, 0.7) : Qt.alpha(tokens.color.border, 0.6)
    HoverHandler { id: hover }
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
        x: 12; y: 6; width: parent.width - 24; height: parent.height - 12
        spacing: 12
        NotificationThumb {
            tokens: root.tokens
            record: root.record
            size: thumbWide ? 34 : 24
            readonly property bool thumbWide: hasImage && wide
            Layout.alignment: Qt.AlignVCenter
        }
        IslandLabel {
            tokens: root.tokens
            text: root.record.summary || root.record.appName || ""
            font.family: root.tokens.type.display.family
            font.pixelSize: 15
            font.weight: Font.Medium
            maximumLineCount: 1
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(80, content.width * 0.45)
        }
        IslandLabel {
            tokens: root.tokens
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.record.body || ""
            color: root.tokens.color.textMuted
            font.pixelSize: 13
            maximumLineCount: 1
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
        IslandLabel {
            tokens: root.tokens
            text: List.relativeTime(root.now, root.record.time)
            color: root.tokens.color.textMuted
            font.pixelSize: 12
            wrapMode: Text.NoWrap
            Layout.alignment: Qt.AlignVCenter
        }
        // Одна ячейка: точка «не прочитано», при наведении — «×»; шеврон показывает, что строка нажимается.
        Item {
            Layout.preferredWidth: 28; Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: root.tokens.color.accent
                visible: !root.record.read && !root.hovered
            }
            NotificationClose {
                anchors.centerIn: parent
                tokens: root.tokens
                visible: root.hovered
                onClicked: if (root.notifications) root.notifications.remove(root.record.id)
            }
        }
        Glyph {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 14; Layout.preferredHeight: 14
            name: "chevronRight"
            ink: root.tokens.color.textMuted
        }
    }
}
