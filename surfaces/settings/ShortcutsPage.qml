pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell

Column {
    id: root
    required property var tokens
    required property var service
    readonly property var manager: service || ({allRows: [], conflicts: [], draftConflicts: [], warnings: [],
        ready: false, busy: true, validateAvailable: false, modExplicit: true, error: "", notice: "",
        shellActions: [], niriActions: [], recording: false})
    readonly property alias editorObject: editor
    function edit(row) { editor.begin(row) }
    property string category: ""
    property string source: ""
    property bool onlyConflicts: false
    spacing: 12
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    readonly property var categories: ["Windows", "Focus", "Move", "Resize", "Workspaces", "Displays", "Apps", "Shell", "Media", "Hardware", "Mouse", "Custom"].filter(name => manager.allRows.some(row => row.category === name))
    readonly property var sources: [{key: "", label: "Все источники"}].concat(Array.from(new Set(manager.allRows.map(row => row.source))).map(name => ({key: name, label: name})))
    readonly property var shown: manager.allRows.filter(function(row) {
        const text = search.text.trim().toLocaleLowerCase().replace(/\s*\+\s*/g, "+")
        return (!category || row.category === category) && (!source || row.source === source)
            && (!onlyConflicts || conflictsFor(row.id).length > 0)
            && (!text || (row.title + " " + row.keys + " " + row.action).toLocaleLowerCase().indexOf(text) >= 0)
    })
    function conflictsFor(id) { return manager.conflicts.filter(item => item.ids.indexOf(id) >= 0) }
    Flow {
        width: parent.width
        spacing: 6
        SettingsChip { tokens: root.tokens; text: "Все"; checked: root.category === ""; onClicked: root.category = "" }
        Repeater {
            model: root.categories
            delegate: SettingsChip {
                required property string modelData
                tokens: root.tokens
                text: modelData
                checked: root.category === modelData
                onClicked: root.category = modelData
            }
        }
    }
    SettingsField { id: search; objectName: "keybindSearch"; tokens: root.tokens; placeholderText: "Действие или сочетание"; Accessible.name: "Поиск сочетаний" }
    Flow {
        width: parent.width
        spacing: 8
        SettingsSelect { tokens: root.tokens; model: root.sources; currentKey: root.source; onActivated: key => root.source = key; Accessible.name: "Источник сочетаний" }
        SettingsChip { tokens: root.tokens; text: "Только конфликты"; checked: root.onlyConflicts; onClicked: root.onlyConflicts = !root.onlyConflicts }
        Action { text: "Создать сочетание"; enabled: root.manager.ready && root.manager.validateAvailable && !root.manager.busy; onClicked: editor.begin(null) }
        Action { text: "Обновить"; enabled: !root.manager.busy; onClicked: root.manager.reload() }
    }
    Row {
        spacing: 8
        visible: !root.manager.modExplicit
        Label { text: "Mod ="; anchors.verticalCenter: parent.verticalCenter }
        SettingsSelect {
            tokens: root.tokens
            model: [{key: "Super", label: "Super · обычный сеанс"}, {key: "Alt", label: "Alt · Niri в окне"}]
            currentKey: root.manager.mod
            onActivated: function(key) { root.manager.mod = key; root.manager.reload() }
            Accessible.name: "Значение модификатора Mod"
        }
    }
    Label { width: parent.width; text: "Найдено: " + root.shown.length + (root.manager.busy ? " · Обработка…" : ""); color: root.tokens.color.textMuted }
    Label {
        width: parent.width
        font.pixelSize: 13
        color: root.tokens.color.textMuted
        text: "Niri и действия Nayori через IPC проверяются как глобальные. Kitty: только явно заданные map, внутри окна, без редактирования. Горячие клавиши остальных приложений не обнаруживаются. Сброс возвращает комбинацию до первой правки в менеджере."
    }
    Label { visible: !root.manager.validateAvailable && root.manager.ready; width: parent.width; text: "niri validate недоступен. Запись сочетаний отключена."; color: root.tokens.color.secondary }
    Label { visible: root.manager.error !== ""; width: parent.width; text: root.manager.error; color: root.tokens.color.secondary }
    Label { visible: root.manager.notice !== ""; width: parent.width; text: root.manager.notice; color: root.tokens.color.accent }
    Repeater {
        model: root.manager.warnings
        delegate: Label { required property string modelData; width: root.width; text: modelData; color: root.tokens.color.secondary; font.pixelSize: 13 }
    }
    Repeater {
        model: root.shown
        delegate: SettingsCard {
            id: bind
            required property var modelData
            width: root.width
            tokens: root.tokens
            padding: 12
            highlighted: root.conflictsFor(modelData.id).length > 0
            property bool deleting: false
            Label { width: parent.width; text: bind.modelData.title; opacity: bind.modelData.enabled ? 1 : 0.6 }
            Flow {
                width: parent.width
                spacing: 4
                Repeater {
                    model: bind.modelData.keys ? bind.modelData.keys.split("+") : ["Не назначено"]
                    delegate: Rectangle {
                        required property string modelData
                        width: keycap.implicitWidth + 16
                        height: 28
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.color: root.tokens.color.border
                        border.width: 1
                        Label { id: keycap; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 13 }
                    }
                }
            }
            Label {
                width: parent.width
                font.pixelSize: 12
                color: root.tokens.color.textMuted
                text: bind.modelData.category + " · " + bind.modelData.source + (bind.modelData.enabled ? "" : " · Отключено")
                    + (bind.modelData.shadowedBy ? " · Переопределено: " + bind.modelData.shadowedBy : "")
                    + (bind.modelData.path ? " · " + bind.modelData.path : "")
            }
            Label { width: parent.width; visible: !bind.modelData.editable; text: bind.modelData.reason || "Только чтение"; font.pixelSize: 12; color: root.tokens.color.textMuted }
            Flow {
                width: parent.width
                spacing: 8
                enabled: !root.manager.busy
                Action { visible: bind.modelData.editable; enabled: root.manager.validateAvailable; text: "Изменить"; onClicked: editor.begin(bind.modelData) }
                Action {
                    visible: bind.modelData.editable && bind.modelData.defaultKeys && bind.modelData.keys !== bind.modelData.defaultKeys
                    enabled: root.manager.validateAvailable
                    text: "Сбросить"
                    onClicked: root.manager.apply({operation: "reset", id: bind.modelData.id})
                }
                Action {
                    visible: bind.modelData.custom || bind.modelData.adapter === "native"
                    enabled: bind.modelData.adapter === "native" || root.manager.validateAvailable
                    text: bind.modelData.enabled ? "Отключить" : "Включить"
                    onClicked: bind.modelData.adapter === "native" ? root.manager.toggleSuper() : root.manager.apply({operation: "toggle", id: bind.modelData.id})
                }
                Action {
                    visible: bind.modelData.custom
                    enabled: root.manager.validateAvailable
                    text: bind.deleting ? "Подтвердить удаление" : "Удалить"
                    onClicked: {
                        if (bind.deleting) root.manager.apply({operation: "delete", id: bind.modelData.id})
                        else bind.deleting = true
                    }
                }
                Action { visible: bind.deleting; text: "Отмена"; onClicked: bind.deleting = false }
            }
            Repeater {
                model: root.conflictsFor(bind.modelData.id)
                delegate: Label {
                    required property var modelData
                    width: parent.width
                    font.pixelSize: 13
                    color: root.tokens.color.secondary
                    text: (modelData.severity === "confirmed" ? "Конфликт: " : "Возможное пересечение: ")
                        + modelData.actions.join(" ↔ ") + " · " + modelData.sources.join(" / ") + "\n" + modelData.reason + ". " + modelData.suggestion
                }
            }
        }
    }
    Label {
        width: parent.width
        text: "Конфликтов: " + root.manager.conflicts.filter(item => item.severity === "confirmed").length
            + " · Возможных пересечений: " + root.manager.conflicts.filter(item => item.severity === "potential").length
        color: root.tokens.color.textMuted
    }
    KeybindEditor {
        id: editor
        tokens: root.tokens
        service: root.manager
        ownerWindow: root.QsWindow.window
        parent: Overlay.overlay
        onSubmitted: change => root.manager.apply(change)
    }
    Connections { target: root.service; function onSaved() { editor.close() } }
    Component.onDestruction: if (service) service.recording = false
}
