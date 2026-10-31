pragma ComponentBehavior: Bound

import QtQuick

// Layout editor for desktop widgets. The parent owns persistence:
// layoutEdited carries the full desktopWidgets map, editModeChanged carries
// arrangement mode. This page does not write settings.
Column {
    id: root
    objectName: "widgets-page"
    required property var tokens
    property bool showHeading: true
    property var desktopWidgets: ({})
    property var screens: []
    property bool editing: false
    property string selectedScreen: ""
    signal layoutEdited(var desktopWidgets)
    signal editModeChanged(bool on)

    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }

    readonly property var screenNames: root.namesFrom(root.screens)
    readonly property var screenOptions: root.optionsFrom(root.screenNames)
    readonly property string activeScreen: root.pickScreen(root.screenNames, root.selectedScreen)
    readonly property bool currentSnap: root.snapOf(root.desktopWidgets, root.activeScreen)
    readonly property var currentItems: root.itemsOf(root.desktopWidgets, root.activeScreen)
    readonly property var sizeOptions: [
        {key: "compact", label: "Компактный"},
        {key: "large", label: "Крупный"}
    ]
    readonly property var styleOptions: [
        {key: "plain", label: "Простой"},
        {key: "card", label: "Карточка"}
    ]
    property int idNonce: 0

    function reveal(item) {
        if (!item)
            return
        let node = root.parent
        while (node) {
            if (node.reveal) {
                node.reveal(item)
                return
            }
            node = node.parent
        }
    }

    function namesFrom(list) {
        const names = []
        const seen = {}
        if (!list || typeof list.length !== "number" || typeof list === "string")
            return names
        for (let i = 0; i < list.length; ++i) {
            const entry = list[i]
            let name = ""
            if (typeof entry === "string")
                name = entry.trim()
            else if (entry && entry.name !== undefined && entry.name !== null)
                name = ("" + entry.name).trim()
            if (!name || seen[name])
                continue
            seen[name] = true
            names.push(name)
        }
        return names
    }

    function optionsFrom(names) {
        const options = []
        const list = names || []
        for (let i = 0; i < list.length; ++i)
            options.push({key: list[i], label: list[i]})
        return options
    }

    function pickScreen(names, selected) {
        const list = names || []
        for (let i = 0; i < list.length; ++i)
            if (list[i] === selected)
                return selected
        return list.length > 0 ? list[0] : ""
    }

    function outputOf(map, name) {
        if (!map || !name || typeof map !== "object" || Array.isArray(map))
            return null
        const entry = map[name]
        if (!entry || typeof entry !== "object" || Array.isArray(entry))
            return null
        return entry
    }

    function snapOf(map, name) {
        const entry = root.outputOf(map, name)
        if (!entry || typeof entry.snap !== "boolean")
            return true
        return entry.snap
    }

    function isList(value) {
        if (Array.isArray(value))
            return true
        if (typeof value === "string" || !value || typeof value !== "object")
            return false
        if (typeof value.length !== "number" || !isFinite(value.length) || value.length < 0)
            return false
        // Variant lists survive a settings round-trip with a length. Output maps
        // are keyed by connector name, so any non-numeric key means this is not a list.
        const keys = Object.keys(value)
        if (value.length === 0)
            return keys.length === 0 || (keys.length === 1 && keys[0] === "length")
        for (let i = 0; i < keys.length; ++i) {
            if (keys[i] === "length")
                continue
            if (!/^\d+$/.test(keys[i]))
                return false
        }
        return true
    }

    function asArray(value) {
        if (!root.isList(value))
            return []
        const copy = []
        for (let i = 0; i < value.length; ++i)
            copy.push(value[i])
        return copy
    }

    function itemsOf(map, name) {
        const entry = root.outputOf(map, name)
        if (!entry)
            return []
        return root.asArray(entry.items)
    }

    function cloneValue(value) {
        if (value === null || value === undefined)
            return value
        if (root.isList(value)) {
            const copy = []
            for (let i = 0; i < value.length; ++i)
                copy.push(root.cloneValue(value[i]))
            return copy
        }
        if (typeof value !== "object")
            return value
        const copy = {}
        const keys = Object.keys(value)
        for (let i = 0; i < keys.length; ++i)
            copy[keys[i]] = root.cloneValue(value[keys[i]])
        return copy
    }

    function cloneMap(source) {
        try {
            if (!source || typeof source !== "object" || Array.isArray(source))
                return {}
            return root.cloneValue(source)
        } catch (error) {
            return null
        }
    }

    function usedIds(map) {
        const used = {}
        if (!map)
            return used
        const outputs = Object.keys(map)
        for (let i = 0; i < outputs.length; ++i) {
            const items = root.asArray(map[outputs[i]] && map[outputs[i]].items)
            for (let j = 0; j < items.length; ++j) {
                const item = items[j]
                if (!item || item.id === undefined || item.id === null)
                    continue
                const id = "" + item.id
                if (id !== "")
                    used[id] = true
            }
        }
        return used
    }

    function freshId(map) {
        root.idNonce += 1
        const used = root.usedIds(map)
        let id = "w-" + Date.now().toString(36) + "-" + root.idNonce.toString(36)
        let extra = 0
        while (used[id]) {
            extra += 1
            id = "w-" + Date.now().toString(36) + "-" + root.idNonce.toString(36) + "-" + extra.toString(36)
        }
        return id
    }

    function placeFor(items) {
        const list = root.asArray(items)
        const step = 24
        const occupied = {}
        for (let i = 0; i < list.length; ++i) {
            const item = list[i]
            if (!item || typeof item !== "object")
                continue
            const x = Math.round(Number(item.x) || 0)
            const y = Math.round(Number(item.y) || 0)
            occupied[x + ":" + y] = true
        }
        for (let slot = 0; slot < 20; ++slot) {
            const x = 48 + slot * step
            const y = 48 + slot * step
            if (!occupied[x + ":" + y])
                return {x: x, y: y}
        }
        return {x: 48 + list.length * step, y: 48 + list.length * step}
    }

    function ensureOutput(map, name) {
        let entry = map[name]
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
            entry = {snap: true, items: []}
            map[name] = entry
            return entry
        }
        entry.items = root.asArray(entry.items).slice()
        if (typeof entry.snap !== "boolean")
            entry.snap = true
        return entry
    }

    function typeLabel(type) {
        if (type === "clock")
            return "Часы"
        if (type === "weather")
            return "Погода"
        if (type === "music")
            return "Музыка"
        if (type === "system")
            return "Система"
        if (type === "note")
            return "Заметка"
        return "Виджет"
    }

    function notePreview(item) {
        if (!item || item.type !== "note" || typeof item.text !== "string")
            return ""
        const flat = item.text.replace(/\s+/g, " ").trim()
        if (!flat)
            return ""
        if (flat.length <= 48)
            return flat
        return flat.slice(0, 47) + "…"
    }

    function addWidget(type, size, style) {
        const allowed = type === "clock" || type === "weather" || type === "music" || type === "system" || type === "note"
        const name = root.activeScreen
        if (!allowed || !name)
            return
        const map = root.cloneMap(root.desktopWidgets)
        if (!map)
            return
        const entry = root.ensureOutput(map, name)
        const place = root.placeFor(entry.items)
        entry.items.push({
            id: root.freshId(map),
            type: type,
            x: place.x,
            y: place.y,
            size: size === "large" ? "large" : "compact",
            style: style === "plain" ? "plain" : "card"
        })
        root.layoutEdited(map)
    }

    function sameItem(item, id, index, at) {
        if (!item || typeof item !== "object")
            return false
        if (id !== undefined && id !== null && ("" + id) !== "")
            return ("" + item.id) === ("" + id)
        return index === at
    }

    function updateItem(id, index, field, value) {
        if (field === "size" && value !== "compact" && value !== "large")
            return
        if (field === "style" && value !== "plain" && value !== "card")
            return
        const name = root.activeScreen
        if (!name)
            return
        const map = root.cloneMap(root.desktopWidgets)
        if (!map)
            return
        const entry = map[name]
        if (!entry || typeof entry !== "object")
            return
        const items = root.asArray(entry.items)
        let changed = false
        for (let i = 0; i < items.length; ++i) {
            if (!root.sameItem(items[i], id, i, index))
                continue
            if (items[i][field] === value)
                return
            items[i][field] = value
            changed = true
            break
        }
        if (!changed)
            return
        entry.items = items
        root.layoutEdited(map)
    }

    function removeItem(id, index) {
        const name = root.activeScreen
        if (!name)
            return
        const map = root.cloneMap(root.desktopWidgets)
        if (!map)
            return
        const entry = map[name]
        if (!entry || typeof entry !== "object")
            return
        const items = root.asArray(entry.items)
        const next = []
        let removed = false
        for (let i = 0; i < items.length; ++i) {
            if (!removed && root.sameItem(items[i], id, i, index)) {
                removed = true
                continue
            }
            next.push(items[i])
        }
        if (!removed)
            return
        entry.items = next
        root.layoutEdited(map)
    }

    function setSnap(enabled) {
        const name = root.activeScreen
        if (!name)
            return
        const next = !!enabled
        const entry = root.outputOf(root.desktopWidgets, name)
        if (entry && typeof entry.snap === "boolean" && entry.snap === next)
            return
        const map = root.cloneMap(root.desktopWidgets)
        if (!map)
            return
        root.ensureOutput(map, name).snap = next
        root.layoutEdited(map)
    }

    function toggleEditing() {
        const next = !root.editing
        root.editModeChanged(next)
        // Keep an incoming binding if the parent applied `next` in the handler.
        if (root.editing !== next)
            root.editing = next
    }

    Label {
        objectName: "widgets-heading"
        visible: root.showHeading
        width: parent.width
        text: "Виджеты"
        font.family: root.tokens.type.display.family
        font.pixelSize: 20
    }

    SettingsCard {
        objectName: "widgets-empty-screens"
        visible: root.screenNames.length === 0
        tokens: root.tokens
        title: "Подключённых экранов нет"
        subtitle: "Подключите монитор, чтобы добавить виджеты"
    }

    SettingsCard {
        objectName: "widgets-monitor-card"
        visible: root.screenNames.length > 1
        tokens: root.tokens
        title: "Монитор"
        subtitle: "У\u00A0каждого монитора свой набор виджетов"
        SettingsSelect {
            objectName: "widgets-monitor"
            width: Math.min(320, parent.width)
            tokens: root.tokens
            model: root.screenOptions
            currentKey: root.activeScreen
            Accessible.name: "Монитор"
            onActivated: key => { root.selectedScreen = key }
            onFocusReceived: root.reveal(this)
        }
    }

    Label {
        objectName: "widgets-single-screen"
        visible: root.screenNames.length === 1
        width: parent.width
        text: "Монитор " + root.activeScreen
        color: root.tokens.color.textMuted
        font.pixelSize: root.tokens.type.small.size
    }

    SettingsCard {
        objectName: "widgets-arrange"
        visible: root.screenNames.length > 0 || root.editing
        tokens: root.tokens
        title: "Расстановка"
        subtitle: "Перетаскивать виджеты можно только в\u00A0режиме расстановки"
        SettingsButton {
            objectName: "widgets-edit"
            tokens: root.tokens
            primary: true
            text: root.editing ? "Закончить расстановку" : "Расставить виджеты"
            Accessible.name: text
            onClicked: root.toggleEditing()
            onActiveFocusChanged: if (activeFocus) root.reveal(this)
        }
        SettingsSwitch {
            objectName: "widgets-snap"
            visible: root.activeScreen !== ""
            tokens: root.tokens
            text: "Притягивать к\u00A0сетке"
            checked: root.currentSnap
            onClicked: root.setSnap(!root.currentSnap)
            onFocusReceived: root.reveal(this)
        }
    }

    SettingsCard {
        objectName: "widgets-add"
        visible: root.activeScreen !== ""
        tokens: root.tokens
        title: "Новый виджет"
        Flow {
            width: parent.width
            spacing: 8
            SettingsButton {
                objectName: "widgets-add-clock"
                tokens: root.tokens
                text: "Добавить часы"
                onClicked: root.addWidget("clock", "compact", "card")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
            SettingsButton {
                objectName: "widgets-add-clock-large"
                tokens: root.tokens
                text: "Добавить крупные часы"
                onClicked: root.addWidget("clock", "large", "plain")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
            SettingsButton {
                objectName: "widgets-add-weather"
                tokens: root.tokens
                text: "Добавить погоду"
                onClicked: root.addWidget("weather", "compact", "card")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
            SettingsButton {
                objectName: "widgets-add-music"
                tokens: root.tokens
                text: "Добавить музыку"
                onClicked: root.addWidget("music", "compact", "card")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
            SettingsButton {
                objectName: "widgets-add-system"
                tokens: root.tokens
                text: "Добавить систему"
                onClicked: root.addWidget("system", "compact", "card")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
            SettingsButton {
                objectName: "widgets-add-note"
                tokens: root.tokens
                text: "Добавить заметку"
                onClicked: root.addWidget("note", "compact", "card")
                onActiveFocusChanged: if (activeFocus) root.reveal(this)
            }
        }
    }

    SettingsCard {
        objectName: "widgets-list"
        visible: root.activeScreen !== ""
        tokens: root.tokens
        title: "На экране"
        Label {
            objectName: "widgets-list-empty"
            visible: root.currentItems.length === 0
            width: parent.width
            text: "На этом мониторе виджетов нет"
            color: root.tokens.color.textMuted
            font.pixelSize: root.tokens.type.small.size
        }
        Repeater {
            model: root.currentItems
            delegate: Column {
                id: widgetRow
                required property var modelData
                required property int index
                width: parent.width
                spacing: 8

                Rectangle {
                    visible: widgetRow.index > 0
                    width: parent.width
                    height: 1
                    color: root.tokens.color.border
                }
                Row {
                    width: parent.width
                    spacing: 8
                    Column {
                        width: Math.max(0, parent.width - removeButton.implicitWidth - 8)
                        spacing: 2
                        Label {
                            width: parent.width
                            text: root.typeLabel(widgetRow.modelData && widgetRow.modelData.type)
                        }
                        Label {
                            visible: root.notePreview(widgetRow.modelData) !== ""
                            width: parent.width
                            text: root.notePreview(widgetRow.modelData)
                            color: root.tokens.color.textMuted
                            font.pixelSize: root.tokens.type.small.size
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }
                    }
                    SettingsButton {
                        id: removeButton
                        objectName: "widgets-remove-" + widgetRow.index
                        tokens: root.tokens
                        text: "Удалить"
                        Accessible.name: "Удалить, " + root.typeLabel(widgetRow.modelData && widgetRow.modelData.type)
                        onClicked: root.removeItem(widgetRow.modelData && widgetRow.modelData.id, widgetRow.index)
                        onActiveFocusChanged: if (activeFocus) root.reveal(this)
                    }
                }
                Label { text: "Размер" }
                SettingsSelect {
                    objectName: "widgets-size-" + widgetRow.index
                    width: Math.min(280, parent.width)
                    tokens: root.tokens
                    model: root.sizeOptions
                    currentKey: widgetRow.modelData && widgetRow.modelData.size === "large" ? "large" : "compact"
                    Accessible.name: "Размер, " + root.typeLabel(widgetRow.modelData && widgetRow.modelData.type)
                    onActivated: key => root.updateItem(widgetRow.modelData && widgetRow.modelData.id, widgetRow.index, "size", key)
                    onFocusReceived: root.reveal(this)
                }
                Label { text: "Оформление" }
                SettingsSelect {
                    objectName: "widgets-style-" + widgetRow.index
                    width: Math.min(280, parent.width)
                    tokens: root.tokens
                    model: root.styleOptions
                    currentKey: widgetRow.modelData && widgetRow.modelData.style === "plain" ? "plain" : "card"
                    Accessible.name: "Оформление, " + root.typeLabel(widgetRow.modelData && widgetRow.modelData.type)
                    onActivated: key => root.updateItem(widgetRow.modelData && widgetRow.modelData.id, widgetRow.index, "style", key)
                    onFocusReceived: root.reveal(this)
                }
            }
        }
    }
}
