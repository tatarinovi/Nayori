import QtQuick
import "VisualizerConfig.js" as Config

// One session owner; persistence belongs exclusively to SettingsService.
QtObject {
    id: root
    required property var settings
    property string selectedId: ""
    property var stageSession: null
    onSelectedIdChanged: {
        if (!stageSession) return
        if (selectedId !== "" && stageSession.selected !== "visualizer:" + selectedId)
            stageSession.select("visualizer:" + selectedId)
        else if (selectedId === "" && stageSession.selected.indexOf("visualizer:") === 0)
            stageSession.remove(stageSession.selected)
    }
    property Connections stageConnections: Connections {
        target: root.stageSession
        function onSelectionChanged() {
            const id = root.stageSession.selected
            const next = id.indexOf("visualizer:") === 0 ? id.slice(11) : ""
            if (root.selectedId !== next) root.selectedId = next
        }
    }
    readonly property var config: settings.desktopVisualizers
    readonly property var items: config.items
    readonly property var selected: items.find(item => item.id === selectedId) || null
    function onOutput(output) { return items.filter(item => item.output === output) }
    function select(id) { selectedId = id }
    function save(items) { settings.update({desktopVisualizers: Object.assign({}, config, {items: items})}) }
    function add(output) {
        const id = "viz-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10)
        const item = Config.normalizeItem({id: id, output: output, style: "curtain"})
        save(items.concat([item]))
        selectedId = id
        return id
    }
    function patch(id, changes) {
        save(items.map(item => item.id === id ? Config.normalizeItem(Object.assign({}, item, changes)) : item))
    }
    function remove(id) {
        save(items.filter(item => item.id !== id))
        if (selectedId === id) selectedId = ""
    }
    function budget(key, value) {
        const next = Object.assign({}, config)
        next[key] = value
        settings.update({desktopVisualizers: next})
    }
    function flip(id) {
        const item = items.find(v => v.id === id)
        if (!item) return
        if (item.style === "aura") patch(id, {auraFlow: item.auraFlow === "clockwise" ? "counterclockwise" : "clockwise"})
        else if (["radial", "orb", "spiral"].indexOf(item.style) >= 0) patch(id, {spin: -item.spin})
        else {
            const opposite = {up: "down", down: "up", left: "right", right: "left"}
            patch(id, opposite[item.grow] ? {grow: opposite[item.grow]} : {mirror: !item.mirror})
        }
    }
}
