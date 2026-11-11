pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../settings"
import "WidgetCatalogData.js" as CatalogData

Column {
    id: root
    required property var tokens
    property bool canAdd: true
    property bool completed: false
    property string query: ""
    property var expandedSections: ({})
    property var snapshots: ({})
    property var failedPreviews: ({})
    property string renderingKey: ""
    readonly property var sets: CatalogData.sets(query)
    readonly property int columns: width >= 260 ? 2 : 1
    readonly property int previewCount: Object.keys(snapshots).length
    readonly property var visibleEntries: {
        let rows = []
        for (const set of sets) {
            if (!isExpanded("set:" + set.key)) continue
            for (const type of set.types)
                if (isExpanded("type:" + set.key + ":" + type.key)) rows = rows.concat(type.items)
        }
        return rows
    }
    signal addRequested(string type, string size, string style)
    spacing: 16
    function isExpanded(key) { return expandedSections[key] === true || (query.trim() !== "" && expandedSections[key] !== false) }
    function toggleSection(key) {
        const next = Object.assign({}, expandedSections)
        next[key] = !isExpanded(key)
        expandedSections = next
    }
    function enqueuePreviews() { if (completed) dispatch.restart() }
    function nextPreview() {
        if (!visible || renderingKey !== "") return
        for (const row of visibleEntries) {
            const key = CatalogData.key(row)
            if (snapshots[key] || failedPreviews[key]) continue
            renderingKey = key
            renderer.request(key, {id:"preview", type:row.id, size:row.size, style:row.style, x:0, y:0})
            return
        }
    }
    onVisibleEntriesChanged: {
        if (!completed) return
        if (renderingKey !== "" && !visibleEntries.some(row => CatalogData.key(row) === renderingKey)) {
            renderer.cancel()
            renderingKey = ""
        }
        enqueuePreviews()
    }
    onVisibleChanged: {
        if (!completed) return
        if (!visible) {
            renderer.cancel()
            renderingKey = ""
            snapshots = ({})
            failedPreviews = ({})
        } else enqueuePreviews()
    }
    Component.onCompleted: { completed = true; enqueuePreviews() }
    SettingsField {
        tokens: root.tokens
        width: parent.width
        objectName: "widget-catalog-search"
        text: root.query
        placeholderText: "Поиск виджетов"
        Accessible.name: "Поиск виджетов"
        onTextEdited: root.query = text
    }
    Repeater {
        model: root.sets
        delegate: Column {
            id: setRow
            required property var modelData
            width: root.width
            spacing: 8
            readonly property string sectionKey: "set:" + modelData.key
            readonly property bool expanded: root.isExpanded(sectionKey)
            WidgetCatalogHeader {
                width: parent.width
                objectName: "widget-catalog-set-" + setRow.modelData.key
                tokens: root.tokens
                text: setRow.modelData.label
                count: setRow.modelData.count
                expanded: setRow.expanded
                onClicked: root.toggleSection(setRow.sectionKey)
            }
            Loader {
                x: 8; width: parent.width - 8
                active: setRow.expanded && root.visible
                visible: active
                height: active && item ? item.implicitHeight : 0
                sourceComponent: Column {
                    width: setRow.width - 8
                    spacing: 12
                    Repeater {
                        model: setRow.modelData.types
                        delegate: Column {
                            id: typeRow
                            required property var modelData
                            width: setRow.width - 8
                            spacing: 8
                            readonly property string sectionKey: "type:" + setRow.modelData.key + ":" + modelData.key
                            readonly property bool expanded: root.isExpanded(sectionKey)
                            WidgetCatalogHeader {
                                width: parent.width
                                objectName: "widget-catalog-type-" + setRow.modelData.key + "-" + typeRow.modelData.key
                                tokens: root.tokens
                                text: typeRow.modelData.label
                                count: typeRow.modelData.items.length
                                expanded: typeRow.expanded
                                nested: true
                                onClicked: root.toggleSection(typeRow.sectionKey)
                            }
                            Loader {
                                width: parent.width
                                active: typeRow.expanded && root.visible
                                visible: active
                                height: active && item ? item.implicitHeight : 0
                                sourceComponent: Grid {
                                    width: typeRow.width
                                    columns: root.columns
                                    spacing: 8
                                    Repeater {
                                        model: typeRow.modelData.items
                                        delegate: WidgetCatalogCard {
                                            required property var modelData
                                            width: Math.floor((typeRow.width - 8 * (root.columns - 1)) / root.columns)
                                            tokens: root.tokens
                                            entry: modelData
                                            snapshot: root.snapshots[CatalogData.key(modelData)] || null
                                            enabled: root.canAdd
                                            onClicked: root.addRequested(modelData.id, modelData.size, modelData.style)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: root.sets.length === 0
        width: parent.width
        text: "Виджеты не найдены"
        wrapMode: Text.WordWrap
        color: root.tokens.color.textMuted
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
    }
    Timer { id: dispatch; interval: 0; onTriggered: root.nextPreview() }
    Item {
        width: 0; height: 0; clip: true
        WidgetPreviewRenderer {
            id: renderer
            tokens: root.tokens
            onRendered: (key, result) => {
                if (root.visible && root.visibleEntries.some(row => CatalogData.key(row) === key)) {
                    const next = Object.assign({}, root.snapshots)
                    next[key] = result
                    root.snapshots = next
                }
                root.renderingKey = ""
                root.enqueuePreviews()
            }
            onRenderFailed: key => {
                const next = Object.assign({}, root.failedPreviews)
                next[key] = true
                root.failedPreviews = next
                root.renderingKey = ""
                root.enqueuePreviews()
            }
        }
    }
}
