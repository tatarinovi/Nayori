pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "ShelfDrop.js" as ShelfDrop

FocusScope {
    id: root
    required property var tokens
    property var store: null
    property bool draggingOut: false
    property bool acceptingDrop: area.containsDrag
    readonly property bool interacting: draggingOut || acceptingDrop || noteInput.activeFocus || editor.activeFocus
    readonly property var items: store ? store.items.slice().sort((a, b) => Number(b.fav) - Number(a.fav) || b.added - a.added) : []
    property string selectedId: ""
    readonly property var selected: items.find(i => i.id === selectedId) || null
    property string editingId: ""
    readonly property var editing: items.find(i => i.id === editingId) || null
    Component.onDestruction: if (editing) saveNote()
    function saveNote() {
        if (editing && store) store.edit(editingId, editor.text)
        editingId = ""
    }
    function editNote(item) {
        editingId = item.id
        editor.text = item.text
        editor.forceActiveFocus()
    }
    function addNote() {
        if (!store || !noteInput.text.trim()) return
        if (store.add({text: noteInput.text, note: true})) noteInput.clear()
    }
    onVisibleChanged: {
        if (visible && store) store.refresh()
        if (!visible && editing) saveNote()
    }
    Keys.onEscapePressed: event => {
        if (editing) { saveNote(); event.accepted = true }
        else event.accepted = false
    }
    component Label: IslandLabel { tokens: root.tokens }
    component Action: IslandAction { tokens: root.tokens }
    DropArea {
        id: area
        objectName: "shelfDropArea"
        anchors.fill: parent
        onEntered: event => {
            if (!root.store || event.source || !ShelfDrop.supports(event)) { event.accepted = false; return }
            ShelfDrop.prefetch(event)
        }
        onDropped: event => {
            if (root.store && !event.source && root.store.add(ShelfDrop.read(event))) event.accept(Qt.CopyAction)
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: root.editing ? "Заметка" : "Перетащите сюда файл, картинку, ссылку или текст"
                font.pixelSize: 12
                color: root.tokens.color.textMuted
                wrapMode: Text.Wrap
            }
            Label { text: root.items.length + " / 200"; font.pixelSize: 12; color: root.tokens.color.textMuted }
            Action {
                text: "↻"; Accessible.name: "Обновить полку"
                enabled: !!root.store && !root.store.busy
                onClicked: root.store.refresh()
            }
        }
        Label {
            objectName: "shelfError"
            Layout.fillWidth: true
            visible: text !== ""
            text: root.store ? root.store.error : "Служба полки недоступна"
            color: root.tokens.color.secondary
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Rectangle {
                anchors.fill: parent
                radius: root.tokens.radius.medium
                color: area.containsDrag ? Qt.alpha(root.tokens.color.accent, 0.1) : "transparent"
                border.width: area.containsDrag ? 1 : 0
                border.color: root.tokens.color.accent
            }
            Label {
                objectName: "shelfEmpty"
                anchors.centerIn: parent
                width: parent.width - 40
                visible: root.items.length === 0 && !root.editing
                text: root.store && root.store.busy ? "Загружаем…" : "Полка пока пуста\n\nОставьте здесь нужное и перетащите в другое окно позже.\n★ сохраняет элемент, а закреплённая папка принимает файлы."
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: root.tokens.color.textMuted
            }
            ListView {
                id: list
                objectName: "shelfList"
                anchors.fill: parent
                clip: true
                spacing: 8
                visible: !root.editing
                model: root.items
                ScrollBar.vertical: ScrollBar {}
                delegate: IslandCard {
                    id: tile
                    required property var modelData
                    required property int index
                    property bool shelfTile: true
                    objectName: "shelfItem_" + index
                    tokens: root.tokens
                    width: list.width - 12
                    height: 80
                    border.width: root.selectedId === modelData.id || folderDrop.containsDrag ? 1 : 0
                    border.color: root.tokens.color.accent
                    opacity: modelData.missing ? 0.55 : 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12
                        Item {
                            Layout.preferredWidth: 64
                            Layout.fillHeight: true
                            Image {
                                id: preview
                                anchors.fill: parent
                                source: tile.modelData.kind === "image" && !tile.modelData.missing ? tile.modelData.uri : ""
                                asynchronous: true
                                sourceSize.width: 128; sourceSize.height: 128
                                fillMode: Image.PreserveAspectFit
                            }
                            Label {
                                anchors.centerIn: parent
                                visible: preview.status !== Image.Ready
                                text: ({folder: "▣", image: "▧", file: "≡", video: "▷", link: "↗", text: "¶"})[tile.modelData.kind] || "≡"
                                font.pixelSize: 26
                                color: root.tokens.color.accent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Label { Layout.fillWidth: true; text: (tile.modelData.fav ? "★ " : "") + tile.modelData.name; elide: Text.ElideRight; maximumLineCount: 1 }
                            Label {
                                Layout.fillWidth: true
                                text: tile.modelData.missing ? "Файл перемещён или удалён" : tile.modelData.failed ? "Изображение не загрузилось · сохранена ссылка" : tile.modelData.note ? "Заметка · остаётся на полке" : tile.modelData.kind === "folder" && tile.modelData.fav ? "Перетащите сюда файлы для копирования" : tile.modelData.path || tile.modelData.text || tile.modelData.url
                                font.pixelSize: 12
                                color: root.tokens.color.textMuted
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                    TapHandler {
                        onTapped: root.selectedId = tile.modelData.id
                        onDoubleTapped: {
                            root.selectedId = tile.modelData.id
                            if (tile.modelData.kind === "text") root.editNote(tile.modelData)
                            else root.store.open(tile.modelData.id)
                        }
                    }
                    DragHandler {
                        id: drag
                        target: null
                        enabled: !tile.modelData.missing && !root.editing
                        onActiveChanged: if (active) root.draggingOut = true
                    }
                    Drag.active: drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ShelfDrop.mime(modelData)
                    Drag.onDragFinished: action => {
                        if (action !== Qt.IgnoreAction && root.store) root.store.taken(tile.modelData.id)
                        root.draggingOut = false
                    }
                    DropArea {
                        id: folderDrop
                        anchors.fill: parent
                        enabled: tile.modelData.kind === "folder" && tile.modelData.fav && !tile.modelData.missing
                        onEntered: event => {
                            if (event.source === tile || !ShelfDrop.supports(event)) { event.accepted = false; return }
                            ShelfDrop.prefetch(event)
                        }
                        onDropped: event => {
                            const data = ShelfDrop.read(event)
                            if (data.urls && data.urls.length && root.store) {
                                root.store.into(tile.modelData.id, data.urls)
                                event.accept(Qt.CopyAction)
                            }
                        }
                    }
                }
            }
            ScrollView {
                anchors.fill: parent
                visible: !!root.editing
                TextArea {
                    id: editor
                    objectName: "shelfNoteEditor"
                    color: root.tokens.color.text
                    selectionColor: root.tokens.color.accentSoft
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    background: Rectangle { color: Qt.alpha(root.tokens.color.surfaceAlt, 0.35); radius: root.tokens.radius.medium }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !!root.selected && !root.editing
            Action { text: "Копировать"; objectName: "shelfCopy"; enabled: !root.selected || !root.selected.missing; onClicked: root.store.copy(root.selected) }
            Action { text: root.selected && root.selected.kind === "text" ? "Изменить" : "Открыть"; enabled: !root.selected || !root.selected.missing; onClicked: { if (root.selected.kind === "text") root.editNote(root.selected); else root.store.open(root.selectedId) } }
            Action { text: "В папке"; visible: !!root.selected && !!root.selected.path; enabled: !root.selected || !root.selected.missing; onClicked: root.store.folder(root.selectedId) }
            Item { Layout.fillWidth: true }
            Action { text: root.selected && root.selected.fav ? "★" : "☆"; Accessible.name: "Закрепить или открепить"; onClicked: root.store.favorite(root.selectedId) }
            Action { text: "Удалить"; onClicked: root.store.remove(root.selectedId) }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.editing
            TextField {
                id: noteInput
                objectName: "shelfNewNote"
                Layout.fillWidth: true
                placeholderText: "Заметка на потом…"
                Layout.preferredHeight: 36
                maximumLength: 64000
                color: root.tokens.color.text
                placeholderTextColor: root.tokens.color.textMuted
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.type.body.size
                selectByMouse: true
                background: Rectangle { color: Qt.alpha(root.tokens.color.background, 0.28); radius: root.tokens.radius.small; border.width: 1; border.color: root.tokens.color.border }
                onAccepted: root.addNote()
            }
            Action { text: "Вставить"; objectName: "shelfPaste"; Accessible.name: "Вставить из буфера обмена"; enabled: !!root.store && root.store.ready && !root.store.busy && !root.store.pastePending; onClicked: root.store.paste() }
            Action { text: "＋ Заметка"; enabled: !!root.store && root.store.ready && !root.store.busy && noteInput.text.trim() !== ""; onClicked: root.addNote() }
        }
        Action { visible: !!root.editing; text: "Сохранить"; onClicked: root.saveNote() }
        Label {
            Layout.fillWidth: true
            text: root.store && root.store.busy ? "Выполняем действие…" : root.store && root.store.status === "Скопировано" ? root.store.status : "После переноса элемент убирается. Заметки и закреплённые остаются."
            font.pixelSize: 11
            color: root.tokens.color.textMuted
            wrapMode: Text.Wrap
        }
    }
}
