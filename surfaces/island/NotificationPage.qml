pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
FocusScope {
    id: root
    required property var tokens
    property var notifications: null
    signal closeRequested()
    function canScroll(delta) { return list.contentHeight > list.height && (delta > 0 ? !list.atYBeginning : !list.atYEnd) }
    Keys.onEscapePressed: closeRequested()
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 0; spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            IslandAction {
                tokens: root.tokens; text: "Очистить"; enabled: !!root.notifications && root.notifications.records.length > 0; onClicked: root.notifications.clear() }
        }
        IslandLabel {
                tokens: root.tokens
            visible: !root.notifications || root.notifications.records.length === 0
            text: "Уведомлений пока нет"; color: root.tokens.color.textMuted
            font.family: root.tokens.type.body.family; font.pixelSize: root.tokens.type.body.size
        }
        ListView {
            id: list
            objectName: "notificationList"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 12
            model: root.notifications ? root.notifications.records : []
            ScrollBar.vertical: ScrollBar {}
            delegate: IslandCard {
                id: card
                required property var modelData
                tokens: root.tokens
                width: list.width; height: content.implicitHeight + 32
                ColumnLayout {
                    id: content
                    x: 16; y: 16; width: parent.width - 32; spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Image {
                            source: card.modelData.appIcon ? (card.modelData.appIcon.indexOf("/") >= 0 ? card.modelData.appIcon : "image://icon/" + card.modelData.appIcon) : ""
                            visible: source.toString() !== ""
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20; fillMode: Image.PreserveAspectFit
                        }
                        IslandLabel {
                tokens: root.tokens; text: card.modelData.appName; textFormat: Text.PlainText; color: root.tokens.color.textMuted; font.pixelSize: 12; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                        IslandAction {
                tokens: root.tokens; text: "Удалить"; onClicked: root.notifications.remove(card.modelData.id) }
                    }
                    IslandLabel {
                tokens: root.tokens; text: card.modelData.summary; textFormat: Text.PlainText; color: root.tokens.color.text; wrapMode: Text.Wrap; Layout.fillWidth: true; font.family: root.tokens.type.display.family; font.pixelSize: 19; font.weight: Font.Medium }
                    IslandLabel {
                tokens: root.tokens; text: card.modelData.body; textFormat: Text.PlainText; color: root.tokens.color.text; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    IslandLabel {
                tokens: root.tokens
                        visible: card.modelData.closed
                        text: "Закрыто"; color: root.tokens.color.textMuted; font.pixelSize: 12
                    }
                    Flow {
                        Layout.fillWidth: true; Layout.preferredHeight: childrenRect.height; spacing: 6
                        Repeater {
                            model: card.modelData.actions || []
                            delegate: IslandAction {
                tokens: root.tokens
                                required property var modelData
                                text: modelData.text
                                width: Math.min(implicitWidth, content.width)
                                enabled: !card.modelData.closed
                                onClicked: root.notifications.actionRequested(card.modelData.id, modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
