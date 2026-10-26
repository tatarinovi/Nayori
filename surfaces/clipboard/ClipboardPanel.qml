pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../launcher"
import "ClipboardLogic.js" as Logic

Rectangle {
    id: root
    required property var tokens
    required property var store
    property bool interactive: true
    signal closeRequested()
    property string query: ""
    property string filter: "all"
    property string selectedId: ""
    property bool enlarged: false
    property double now: Date.now()
    readonly property var entries: Logic.filtered(store.records, query, filter)
    readonly property var selected: entries.find(record => record.id === selectedId) || null
    readonly property bool narrow: width < 480
    readonly property int selectedIndex: entries.findIndex(record => record.id === selectedId)
    readonly property alias searchInput: search
    readonly property alias imagePreview: picture
    readonly property alias historyList: history

    implicitWidth: 580
    implicitHeight: 520
    radius: tokens.radius.medium
    color: tokens.material.dense
    border.width: 1
    border.color: Qt.alpha(tokens.color.accentBorder, 0.45)
    clip: true

    function focusInput() {
        const win = root.Window.window
        if (root.interactive && win && win.visible && win.active) search.forceActiveFocus(Qt.ShortcutFocusReason)
    }
    function reconcile() {
        const list = root.entries
        if (!list.some(record => record.id === root.selectedId)) root.selectedId = list.length ? list[0].id : ""
        if (!list.length) root.enlarged = false
    }
    function moveSelection(direction) {
        if (!entries.length) return
        const index = Math.max(0, Math.min(entries.length - 1, selectedIndex + direction))
        root.selectedId = entries[index].id
        history.positionViewAtIndex(index, ListView.Contain)
    }
    function copySelected(pasteAfter) { if (selected && !store.copying) store.copy(selected.id, pasteAfter === true) }
    function dismissEscape() {
        if (enlarged) enlarged = false
        else closeRequested()
    }
    onEntriesChanged: reconcile()
    Component.onCompleted: { reconcile(); Qt.callLater(focusInput) }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.dismissEscape(); event.accepted = true }
        else if (event.key === Qt.Key_Down) { root.moveSelection(1); event.accepted = true }
        else if (event.key === Qt.Key_Up) { root.moveSelection(-1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // Buttons keep their native Enter action; the search/list copy the selection.
            if (search.activeFocus || history.activeFocus) { root.copySelected(true); event.accepted = true }
        }
    }
    Connections {
        target: root.store
        function onCopied(identity) { root.closeRequested() }
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() { root.focusInput() }
        function onVisibleChanged() { root.focusInput() }
    }
    Timer { interval: 30000; running: root.visible; repeat: true; onTriggered: root.now = Date.now() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ClipboardLabel {
                tokens: root.tokens
                text: "Буфер обмена"
                font.family: root.tokens.type.display.family
                font.pixelSize: 23
                Layout.maximumWidth: root.width - 200
            }
            ClipboardLabel {
                tokens: root.tokens
                objectName: "clipboardCount"
                text: "· " + root.store.records.length
                color: root.tokens.color.textMuted
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            ClipboardButton {
                objectName: "clipboardClear"
                tokens: root.tokens
                text: "Очистить"
                implicitWidth: 72
                enabled: root.store.ready && !root.store.copying
                onClicked: root.store.clear()
                ToolTip.visible: hovered
                ToolTip.text: "Очистить историю и текущий буфер, включая закрепленные записи"
                ToolTip.delay: 500
            }
            ClipboardButton {
                tokens: root.tokens
                text: "×"
                glyph: "close"
                Accessible.name: "Закрыть"
                implicitWidth: 32
                onClicked: root.closeRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            color: Qt.alpha(root.tokens.color.surfaceAlt, 0.3)
            radius: root.tokens.radius.small
            border.width: 1
            border.color: Qt.alpha(root.tokens.color.border, 0.65)
            LauncherGlyph {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                ink: root.tokens.color.textMuted
            }
            TextField {
                id: search
                objectName: "clipboardSearch"
                x: 34; width: parent.width - 42; height: parent.height
                text: root.query
                onTextEdited: root.query = text
                placeholderText: "Поиск по истории"
                Accessible.name: "Поиск по истории буфера обмена"
                color: root.tokens.color.text
                placeholderTextColor: Qt.alpha(root.tokens.color.textMuted, 0.8)
                selectionColor: root.tokens.color.accent
                selectedTextColor: root.tokens.color.accentText
                font.family: root.tokens.type.body.family
                font.pixelSize: 13
                background: Item {}
                padding: 0
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: [{key:"all", label:"Всё"}, {key:"media", label:"Медиа"},
                        {key:"text", label:"Текст"}, {key:"pinned", label:"Закреплено"}]
                ClipboardButton {
                    required property var modelData
                    tokens: root.tokens
                    text: modelData.label
                    checked: root.filter === modelData.key
                    quiet: true
                    implicitWidth: labelWidth.implicitWidth + (root.narrow ? 14 : 22)
                    onClicked: root.filter = modelData.key
                    Text { id: labelWidth; text: parent.text; visible: false; font.family: root.tokens.type.body.family; font.pixelSize: 12 }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Wide: list and preview. Narrow outputs retain the same controls in two rows.
            ListView {
                id: history
                objectName: "clipboardHistory"
                x: 0; y: 0
                width: root.narrow ? parent.width : 192
                height: root.narrow ? Math.min(150, parent.height * 0.4) : parent.height
                visible: !root.enlarged
                clip: true
                spacing: 4
                model: root.entries
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Button {
                    id: row
                    required property var modelData
                    required property int index
                    objectName: "clipboardEntry_" + index
                    width: history.width - 6
                    height: 62
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    Accessible.name: modelData.title + (modelData.pinned ? ", закреплено" : "")
                    onClicked: { root.selectedId = modelData.id; search.forceActiveFocus() }
                    onDoubleClicked: root.copySelected(true)
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: root.selectedId === row.modelData.id ? Qt.alpha(root.tokens.color.surfaceAlt, 0.8)
                            : row.hovered ? Qt.alpha(root.tokens.color.surfaceAlt, 0.4) : "transparent"
                        border.width: root.selectedId === row.modelData.id ? 1 : 0
                        border.color: Qt.alpha(root.tokens.color.accentBorder, 0.65)
                    }
                    contentItem: Column {
                        spacing: 5
                        ClipboardLabel {
                            tokens: root.tokens
                            width: parent.width
                            text: row.modelData.title
                            rightPadding: row.modelData.pinned ? 18 : 0
                            font.pixelSize: 13
                            ClipboardGlyph {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.modelData.pinned
                                width: 13; height: 13
                                ink: root.tokens.color.accent
                            }
                        }
                        ClipboardLabel {
                            tokens: root.tokens
                            width: parent.width
                            text: (row.modelData.format || Logic.typeLabel(row.modelData))
                                + " · " + Logic.relativeTime(row.modelData.created, root.now)
                            color: root.tokens.color.textMuted
                            font.pixelSize: 11
                        }
                    }
                    leftPadding: 10; rightPadding: 10; topPadding: 11; bottomPadding: 10
                }
            }
            Rectangle {
                x: root.narrow ? 0 : history.width + 3
                y: root.narrow ? history.height + 6 : 0
                width: root.narrow ? parent.width : 1
                height: root.narrow ? 1 : parent.height
                color: Qt.alpha(root.tokens.color.border, 0.5)
                visible: !root.enlarged && root.entries.length > 0
            }
            ColumnLayout {
                id: detail
                x: root.enlarged || root.narrow ? 0 : history.width + 20
                y: root.narrow && !root.enlarged ? history.height + 16 : 0
                width: parent.width - x
                height: parent.height - y
                spacing: 8
                visible: root.selected !== null
                RowLayout {
                    Layout.fillWidth: true
                    ClipboardLabel {
                        tokens: root.tokens
                        text: Logic.typeLabel(root.selected)
                        color: root.tokens.color.textMuted
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }
                    ClipboardButton {
                        tokens: root.tokens
                        text: root.selected && root.selected.pinned ? "Открепить" : "Закрепить"
                        glyph: "pin"
                        objectName: "clipboardPin"
                        checked: root.selected !== null && root.selected.pinned
                        implicitWidth: 32
                        implicitHeight: 28
                        ToolTip.visible: hovered
                        ToolTip.text: text
                        ToolTip.delay: 500
                        onClicked: if (root.selected) root.store.pin(root.selected.id)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 48
                    color: Qt.alpha(root.tokens.color.surfaceAlt, 0.3)
                    radius: root.tokens.radius.small
                    clip: true
                    Image {
                        id: picture
                        objectName: "clipboardImagePreview"
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: root.selected !== null && (root.selected.kind === "image" || root.selected.kind === "video")
                        source: visible ? root.selected.image : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: Math.max(1, Math.ceil(width * (root.Window.window ? root.Window.window.devicePixelRatio : 1)))
                        sourceSize.height: Math.max(1, Math.ceil(height * (root.Window.window ? root.Window.window.devicePixelRatio : 1)))
                        Accessible.role: Accessible.Graphic
                        Accessible.name: root.selected ? root.selected.title : ""
                    }
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: root.selected !== null && (root.selected.kind === "text" || root.selected.kind === "file")
                        clip: true
                        TextArea {
                            text: root.selected ? root.selected.text : ""
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            font.family: root.tokens.type.body.family
                            font.pixelSize: 13
                            color: root.tokens.color.text
                            selectionColor: root.tokens.color.accent
                            selectedTextColor: root.tokens.color.accentText
                            background: Item {}
                        }
                    }
                    ClipboardLabel {
                        tokens: root.tokens
                        anchors.centerIn: parent
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: root.tokens.color.textMuted
                        visible: picture.visible && (picture.status === Image.Error || picture.source.toString() === "")
                        text: root.selected && root.selected.kind === "video" ? "Превью видео недоступно" : "Не удалось показать превью"
                    }
                }
                ClipboardLabel {
                    tokens: root.tokens
                    Layout.fillWidth: true
                    text: root.selected ? root.selected.title : ""
                    font.family: root.tokens.type.display.family
                    font.pixelSize: 17
                    maximumLineCount: 1
                }
                ClipboardLabel {
                    tokens: root.tokens
                    Layout.fillWidth: true
                    objectName: "clipboardMetadata"
                    text: Logic.metadata(root.selected)
                    color: root.tokens.color.textMuted
                    font.pixelSize: 11
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    ClipboardButton {
                        objectName: "clipboardCopy"
                        tokens: root.tokens
                        Layout.fillWidth: true
                        primary: true
                        text: root.store.copying ? "Копирование…" : "Копировать  ↵"
                        enabled: root.store.ready && !root.store.copying && root.selected !== null
                        onClicked: root.copySelected()
                    }
                    ClipboardButton {
                        tokens: root.tokens
                        text: root.enlarged ? "Свернуть" : "Превью"
                        onClicked: root.enlarged = !root.enlarged
                    }
                    ClipboardButton {
                        tokens: root.tokens
                        text: "×"
                        glyph: "trash"
                        Accessible.name: "Удалить запись из журнала"
                        implicitWidth: 32
                        onClicked: if (root.selected) root.store.remove(root.selected.id)
                    }
                }
            }
            ClipboardLabel {
                tokens: root.tokens
                anchors.centerIn: parent
                width: parent.width - 32
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: root.tokens.color.textMuted
                visible: root.entries.length === 0
                text: !root.store.ready ? (root.store.error || "Подключение к буферу обмена…")
                    : root.query !== "" ? "Ничего не нашлось"
                    : root.filter === "pinned" ? "Нет закрепленных записей"
                    : root.filter !== "all" ? "Таких записей пока нет"
                    : "История пуста\nСкопируйте текст или картинку"
            }
        }
        ClipboardLabel {
            tokens: root.tokens
            Layout.fillWidth: true
            visible: root.store.error !== "" && root.entries.length > 0
            text: root.store.error
            color: root.tokens.color.secondary
            font.pixelSize: 12
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Accessible.role: Accessible.AlertMessage
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(root.tokens.color.border, 0.5) }
        RowLayout {
            Layout.fillWidth: true
            ClipboardLabel {
                tokens: root.tokens
                text: "↑↓  выбор     Enter  вставить"
                font.pixelSize: 11
                color: root.tokens.color.textMuted
                Layout.fillWidth: true
            }
            ClipboardLabel { tokens: root.tokens; text: "Esc  закрыть"; font.pixelSize: 11; color: root.tokens.color.textMuted }
        }
    }
}
