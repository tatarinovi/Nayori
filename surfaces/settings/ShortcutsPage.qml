pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell

Item {
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
    readonly property var categoryNames: ({Windows: "Окна", Focus: "Фокус", Move: "Перемещение", Resize: "Размер",
        Workspaces: "Рабочие столы", Displays: "Мониторы", Apps: "Приложения", Shell: "Nayori",
        Media: "Медиа", Hardware: "Устройства", Mouse: "Мышь", Custom: "Пользовательские"})
    readonly property int confirmedCount: manager.conflicts.filter(item => item.severity === "confirmed").length
    readonly property int potentialCount: manager.conflicts.filter(item => item.severity === "potential").length
    property string expandedId: ""
    implicitHeight: 680

    Column {
        id: filters
        width: parent.width
        spacing: 12
        Row {
            width: parent.width
            spacing: 8
            Label {
                width: Math.max(0, parent.width - create.width - refresh.width - 16)
                anchors.verticalCenter: parent.verticalCenter
                text: "Сочетания Niri, Nayori и приложений"
                font.pixelSize: 13
                color: root.tokens.color.textMuted
            }
            Action {
                id: create
                objectName: "createKeybind"
                text: "+ Создать сочетание"
                selected: true
                actionColor: root.tokens.color.accentText
                background: Rectangle { radius: root.tokens.radius.small; color: root.tokens.color.accent }
                enabled: root.manager.ready && root.manager.validateAvailable && !root.manager.busy
                onClicked: editor.begin(null)
            }
            Action { id: refresh; text: "Обновить"; enabled: !root.manager.busy; onClicked: root.manager.reload() }
        }
        Flow {
            width: parent.width
            spacing: 6
            SettingsChip { tokens: root.tokens; text: "Все"; checked: root.category === ""; onClicked: root.category = "" }
            Repeater {
                model: root.categories
                delegate: SettingsChip {
                    required property string modelData
                    tokens: root.tokens
                    text: root.categoryNames[modelData] || modelData
                    checked: root.category === modelData
                    onClicked: root.category = modelData
                }
            }
        }
        Flow {
            width: parent.width
            spacing: 8
            SettingsField {
                id: search
                objectName: "keybindSearch"
                width: Math.max(180, parent.width - 362)
                height: 38
                tokens: root.tokens
                placeholderText: "Найти действие или сочетание"
                Accessible.name: "Поиск сочетаний"
            }
            SettingsSelect {
                width: 170
                tokens: root.tokens
                model: root.sources
                currentKey: root.source
                onActivated: key => root.source = key
                Accessible.name: "Источник сочетаний"
            }
            SettingsChip { tokens: root.tokens; height: 38; text: "Только конфликты"; checked: root.onlyConflicts; onClicked: root.onlyConflicts = !root.onlyConflicts }
        }
        Row {
            width: parent.width
            spacing: 8
            Label {
                width: Math.max(0, parent.width - modChoice.width - 8)
                anchors.verticalCenter: parent.verticalCenter
                text: "Найдено " + root.shown.length + " сочетаний" + (root.manager.busy ? " · Обработка…" : "")
                font.pixelSize: 13
                color: root.tokens.color.textMuted
            }
            SettingsSelect {
                id: modChoice
                visible: !root.manager.modExplicit
                width: visible ? 210 : 0
                tokens: root.tokens
                model: [{key: "Super", label: "Mod = Super"}, {key: "Alt", label: "Mod = Alt · Niri в окне"}]
                currentKey: root.manager.mod || "Super"
                onActivated: function(key) { root.manager.mod = key; root.manager.reload() }
                Accessible.name: "Значение модификатора Mod"
            }
        }
        Label { visible: !root.manager.validateAvailable && root.manager.ready; width: parent.width; text: "niri validate недоступен. Запись сочетаний отключена."; color: root.tokens.color.secondary; font.pixelSize: 13 }
        Label { visible: root.manager.error !== ""; width: parent.width; text: root.manager.error; color: root.tokens.color.secondary; font.pixelSize: 13 }
        Repeater {
            model: root.manager.warnings
            delegate: Label { required property string modelData; width: filters.width; text: modelData; color: root.tokens.color.secondary; font.pixelSize: 13 }
        }
    }
    Rectangle {
        id: table
        anchors { top: filters.bottom; topMargin: 12; bottom: status.top; bottomMargin: 12; left: parent.left; right: parent.right }
        radius: root.tokens.radius.medium
        color: root.tokens.material.sidebar
        border.width: 1
        border.color: root.tokens.color.border
        readonly property real actionWidth: Math.max(120, (width - 112) * 0.43)
        readonly property real keysWidth: Math.max(120, (width - 112) * 0.36)
        readonly property real sourceWidth: Math.max(64, width - actionWidth - keysWidth - 104)
        Item {
            id: tableHeading
            width: parent.width
            height: 40
            Row {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                Label { width: table.actionWidth; text: "Действие"; font.pixelSize: 13; color: root.tokens.color.textMuted }
                Label { width: table.keysWidth; text: "Комбинация"; font.pixelSize: 13; color: root.tokens.color.textMuted }
                Label { width: table.sourceWidth; text: "Источник"; font.pixelSize: 13; color: root.tokens.color.textMuted }
            }
        }
        ListView {
            id: bindings
            objectName: "keybindTable"
            anchors { top: tableHeading.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1; bottomMargin: 8 }
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            delegate: Item {
                id: bind
                required property var modelData
                required property int index
                readonly property var issues: root.conflictsFor(modelData.id)
                readonly property bool expanded: root.expandedId === modelData.id
                property bool deleting: false
                width: bindings.width
                height: mainLine.height + (expanded ? details.implicitHeight + 20 : 0)
                Rectangle {
                    anchors.fill: parent
                    color: bind.issues.length ? Qt.alpha(root.tokens.color.secondary, 0.10)
                        : bind.expanded ? root.tokens.color.surfaceAlt : "transparent"
                }
                Rectangle { width: 3; height: parent.height; visible: bind.issues.length > 0; color: root.tokens.color.secondary }
                Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
                Row {
                    id: mainLine
                    x: 16
                    height: Math.max(54, keyFlow.implicitHeight + 16)
                    opacity: bind.modelData.enabled && bind.modelData.active !== false ? 1 : 0.55
                    Label {
                        width: table.actionWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: bind.modelData.title
                        font.pixelSize: 14
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        rightPadding: 12
                    }
                    Item {
                        width: table.keysWidth
                        height: parent.height
                        Flow {
                            id: keyFlow
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 8
                            spacing: 4
                            Repeater {
                                model: bind.modelData.keys ? bind.modelData.keys.split("+") : ["Не назначено"]
                                delegate: Rectangle {
                                    required property string modelData
                                    width: Math.min(keycap.implicitWidth + 14, table.keysWidth - 16)
                                    height: 27
                                    radius: root.tokens.radius.small
                                    color: root.tokens.color.surfaceAlt
                                    border.color: root.tokens.color.border
                                    border.width: 1
                                    Label {
                                        id: keycap
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, parent.width - 12)
                                        text: modelData
                                        font.pixelSize: 12
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        width: table.sourceWidth
                        height: parent.height
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(sourceText.implicitWidth + 16, parent.width - 8)
                            height: 25
                            radius: 6
                            color: root.tokens.color.surfaceAlt
                            Label {
                                id: sourceText
                                anchors.centerIn: parent
                                text: bind.modelData.source
                                font.pixelSize: 12
                            }
                        }
                    }
                    ToolButton {
                        width: 36; height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        focusPolicy: Qt.StrongFocus
                        enabled: bind.modelData.editable && root.manager.validateAvailable && !root.manager.busy
                        Accessible.name: "Изменить: " + bind.modelData.title
                        onClicked: editor.begin(bind.modelData)
                        contentItem: Label { text: "✎"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: parent.enabled ? 1 : 0.4 }
                        background: Rectangle { radius: 6; color: parent.hovered || parent.visualFocus ? root.tokens.color.surfaceAlt : "transparent"; border.width: parent.visualFocus ? 1 : 0; border.color: root.tokens.color.accent }
                    }
                    ToolButton {
                        width: 36; height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: "Действия: " + bind.modelData.title
                        onClicked: root.expandedId = bind.expanded ? "" : bind.modelData.id
                        contentItem: Label { text: bind.expanded ? "−" : "⋯"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 6; color: parent.hovered || parent.visualFocus ? root.tokens.color.surfaceAlt : "transparent"; border.width: parent.visualFocus ? 1 : 0; border.color: root.tokens.color.accent }
                    }
                }
                Column {
                    id: details
                    x: 16; y: mainLine.height + 6
                    width: parent.width - 32
                    visible: bind.expanded
                    spacing: 8
                    Label {
                        width: parent.width
                        font.pixelSize: 12
                        color: root.tokens.color.textMuted
                        text: (root.categoryNames[bind.modelData.category] || bind.modelData.category)
                            + (bind.modelData.enabled ? "" : " · Отключено")
                            + (bind.modelData.shadowedBy ? " · Переопределено: " + bind.modelData.shadowedBy : "")
                            + (bind.modelData.path ? " · " + bind.modelData.path : "")
                    }
                    Label { width: parent.width; visible: !bind.modelData.editable; text: bind.modelData.reason || "Только чтение"; font.pixelSize: 12; color: root.tokens.color.textMuted }
                    Flow {
                        width: parent.width
                        spacing: 8
                        enabled: !root.manager.busy
                        Action { visible: bind.modelData.editable; enabled: root.manager.validateAvailable; text: "Изменить"; onClicked: editor.begin(bind.modelData) }
                        Action { visible: bind.modelData.editable && !!bind.modelData.defaultKeys && bind.modelData.keys !== bind.modelData.defaultKeys; enabled: root.manager.validateAvailable; text: "Сбросить"; onClicked: root.manager.apply({operation: "reset", id: bind.modelData.id}) }
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
                            onClicked: { if (bind.deleting) root.manager.apply({operation: "delete", id: bind.modelData.id}); else bind.deleting = true }
                        }
                        Action { visible: bind.deleting; text: "Отмена"; onClicked: bind.deleting = false }
                    }
                    Repeater {
                        model: bind.issues
                        delegate: Label {
                            required property var modelData
                            width: details.width
                            font.pixelSize: 13
                            color: root.tokens.color.secondary
                            text: (modelData.severity === "confirmed" ? "Конфликт: " : "Возможное пересечение: ")
                                + modelData.actions.join(" ↔ ") + " · " + modelData.sources.join(" / ") + "\n" + modelData.reason + ". " + modelData.suggestion
                        }
                    }
                }
            }
            Label { anchors.centerIn: parent; visible: bindings.count === 0; text: root.manager.busy ? "Читаем сочетания…" : "Сочетания не найдены"; color: root.tokens.color.textMuted; font.pixelSize: 14 }
        }
    }
    Column {
        id: status
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 8
        Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
        Flow {
            width: parent.width
            spacing: 16
            Label { text: "△  Конфликтов: " + root.confirmedCount; color: root.confirmedCount ? root.tokens.color.secondary : root.tokens.color.textMuted; font.pixelSize: 13 }
            Label { text: "Возможных пересечений: " + root.potentialCount; color: root.tokens.color.textMuted; font.pixelSize: 13 }
            Label { text: root.manager.busy ? "Сохраняем…" : root.manager.error ? "Изменения не сохранены" : root.manager.notice ? "✓  Изменения сохранены" : ""; color: root.tokens.color.textMuted; font.pixelSize: 13 }
        }
        Label {
            width: parent.width
            font.pixelSize: 11
            color: root.tokens.color.textMuted
            text: "Kitty: только заданные map, внутри окна. Другие приложения не проверяются. Сброс — к сочетанию до первой правки."
        }
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
