pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import "../../services/keybinds/KeyCapture.js" as Capture

Popup {
    id: root
    required property var tokens
    required property var service
    property var ownerWindow: null
    property var row: null
    property bool recording: false
    property string forming: ""
    property string kind: "command"
    property string category: "Custom"
    readonly property bool creating: !row || row.adapter === "registry"
    readonly property bool configurable: creating || (row && row.custom === true)
    readonly property var relevantConflicts: service.draftConflicts.filter(item => item.ids.indexOf(creating ? "draft" : row.id) >= 0)
    signal submitted(var change)
    modal: true
    focus: true
    padding: 20
    width: Math.min(parent ? parent.width - 24 : 560, 600)
    height: Math.min(content.implicitHeight + padding * 2, parent ? parent.height - 24 : 760)
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    function change() {
        return {operation: creating ? "create" : configurable ? "update" : "rebind", id: row ? row.id : "", keys: keys.text,
            title: title.text, kind: kind, value: kind === "shell" || kind === "niri" ? actionChoice.currentKey : value.text,
            category: category, enabled: true, appRole: creating ? "" : appRole.currentKey}
    }
    function begin(item) {
        row = item
        kind = item && item.adapter === "registry" ? "shell" : item && item.custom ? item.kind : "command"
        category = item ? item.category : "Custom"
        title.text = item ? item.title : ""
        keys.text = item ? item.keys : ""
        value.text = item && item.custom ? item.value : ""
        actionChoice.currentKey = item && item.adapter === "registry" ? item.action : item && item.custom ? item.value : ""
        appRole.currentKey = ""
        forming = ""
        open()
        service.preview(change())
        keys.forceActiveFocus()
    }
    function stopRecording() { recording = false; service.recording = false; deadline.stop() }
    onRecordingChanged: service.recording = recording
    onClosed: { stopRecording(); service.preview(null) }
    onVisibleChanged: if (!visible) stopRecording()
    background: Rectangle {
        color: root.tokens.color.background
        radius: root.tokens.radius.medium
        border.width: 1
        border.color: root.tokens.color.border
    }
    contentItem: Flickable {
        clip: true
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { }
        Column {
            id: content
            width: parent.width
            spacing: 10
            Label { width: parent.width; text: root.creating ? "Новое сочетание" : root.row.title; font.pixelSize: 20 }
            Label { width: parent.width; text: "Несохранённые изменения"; color: root.tokens.color.accent }
            Label { visible: root.configurable; text: "Название" }
            SettingsField {
                id: title
                objectName: "keybindTitle"
                tokens: root.tokens
                visible: root.configurable
                Accessible.name: "Название действия"
            }
            Label { text: "Комбинация" }
            SettingsField {
                id: keys
                objectName: "keybindKeys"
                tokens: root.tokens
                Accessible.name: "Комбинация клавиш"
                placeholderText: root.recording ? "Нажмите сочетание" : "Super+Return"
                readOnly: root.recording
                onTextChanged: if (root.opened) root.service.preview(root.change())
                Keys.onShortcutOverride: event => { if (root.recording) event.accepted = true }
                Keys.onPressed: function(event) {
                    if (!root.recording) return
                    event.accepted = true
                    if (event.isAutoRepeat) return
                    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) { root.stopRecording(); return }
                    const captured = Capture.chord(event)
                    root.forming = captured.forming
                    if (captured.keys) { keys.text = captured.keys; root.stopRecording() }
                }
                onActiveFocusChanged: if (!activeFocus) root.stopRecording()
            }
            Action {
                text: root.recording ? "Остановить запись" : "Записать с клавиатуры"
                onClicked: {
                    if (root.recording) root.stopRecording()
                    else { keys.forceActiveFocus(); root.recording = true; root.forming = ""; deadline.restart() }
                }
            }
            Label { visible: root.recording; width: parent.width; text: root.forming || "Ожидаем клавишу · Esc отменяет запись" }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: root.recording && !inhibitor.active
                    ? "Перехват глобальных сочетаний недоступен: они могут выполнить действие. Введите комбинацию вручную."
                    : "Записывается символ текущей раскладки. Niri также ищет латинские клавиши в настроенных раскладках. Клавиши мыши и точные имена XKB можно ввести вручную."
            }
            Label {
                width: parent.width
                font.pixelSize: 13
                color: root.tokens.color.textMuted
                text: "Даже при перехвате системные сочетания и бинды с allow-inhibiting=false могут сработать. Запись завершится через 15 секунд."
            }
            SettingsSelect {
                id: appRole
                width: parent.width
                tokens: root.tokens
                visible: !root.configurable && root.row && root.row.category === "Apps"
                model: [{key: "", label: "Сохранить текущее действие"}, {key: "terminal", label: "Терминал по умолчанию"},
                    {key: "browser", label: "Браузер по умолчанию"}, {key: "files", label: "Файловый менеджер по умолчанию"},
                    {key: "editor", label: "Редактор по умолчанию"}, {key: "notes", label: "Заметки по умолчанию"}]
                Accessible.name: "Приложение для сочетания"
                onActivated: key => currentKey = key
            }
            SettingsSelect {
                width: parent.width
                visible: root.configurable
                tokens: root.tokens
                currentKey: root.category
                model: ["Windows", "Focus", "Move", "Resize", "Workspaces", "Displays", "Apps", "Shell", "Media", "Hardware", "Mouse", "Custom"].map(name => ({key: name, label: name}))
                Accessible.name: "Категория"
                onActivated: key => root.category = key
            }
            SettingsSelect {
                width: parent.width
                visible: root.configurable
                tokens: root.tokens
                currentKey: root.kind
                model: [{key: "app", label: "Запуск приложения"}, {key: "command", label: "Команда"},
                    {key: "url", label: "Открытие URL"}, {key: "shell", label: "Действие Nayori"}, {key: "niri", label: "Действие Niri"}]
                Accessible.name: "Тип действия"
                onActivated: function(key) {
                    root.kind = key
                    actionChoice.currentKey = ""
                }
            }
            SettingsSelect {
                id: actionChoice
                tokens: root.tokens
                width: parent.width
                visible: root.configurable && (root.kind === "shell" || root.kind === "niri")
                model: root.kind === "shell" ? root.service.shellActions : root.service.niriActions
                Accessible.name: "Действие"
                onActivated: key => currentKey = key
            }
            SettingsField {
                id: value
                tokens: root.tokens
                visible: root.configurable && root.kind !== "shell" && root.kind !== "niri"
                placeholderText: root.kind === "url" ? "https://example.org" : "Программа и аргументы"
                Accessible.name: "Параметры действия"
            }
            Label {
                width: parent.width
                visible: root.configurable && (root.kind === "app" || root.kind === "command")
                font.pixelSize: 13
                color: root.tokens.color.textMuted
                text: "Аргументы разделяются пробелами; кавычки сохраняют пробелы внутри аргумента. Для конвейера укажите sh -c и команду в кавычках. При проверке команда не запускается."
            }
            Repeater {
                model: root.relevantConflicts
                delegate: Label {
                    required property var modelData
                    width: content.width
                    color: root.tokens.color.secondary
                    text: (modelData.severity === "confirmed" ? "Конфликт: " : "Возможное пересечение: ")
                        + modelData.actions.join(" ↔ ") + " · " + modelData.sources.join(" / ") + "\n" + modelData.reason + ". " + modelData.suggestion
                }
            }
            Label { width: parent.width; visible: root.service.error !== ""; color: root.tokens.color.secondary; text: root.service.error }
            Flow {
                width: parent.width
                spacing: 8
                Action {
                    text: "Сохранить"
                    enabled: !root.service.busy && !root.recording && keys.text.trim() !== ""
                        && (!root.configurable || title.text.trim() !== "")
                    onClicked: { root.stopRecording(); root.submitted(root.change()) }
                }
                Action { text: "Отмена"; enabled: !root.service.busy; onClicked: root.close() }
            }
        }
    }
    ShortcutInhibitor { id: inhibitor; window: root.ownerWindow; enabled: root.recording }
    Timer { id: deadline; interval: 15000; onTriggered: root.stopRecording() }
    Connections {
        target: root.ownerWindow
        function onVisibleChanged() { if (!root.ownerWindow.visible) root.stopRecording() }
    }
}
