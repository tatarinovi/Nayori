.pragma library
.import "WidgetLayout.js" as WidgetLayout

var TYPES = [
    {key: "clock", label: "Часы"},
    {key: "calendar", label: "Дата и календарь"},
    {key: "weather", label: "Погода"},
    {key: "music", label: "Музыка"},
    {key: "system", label: "Система и батарея"},
    {key: "image", label: "Изображения"},
    {key: "notes", label: "Заметки и цитаты"},
    {key: "visualizer", label: "Визуализаторы"},
    {key: "other", label: "Другие виджеты"}
]

function typeOf(id) {
    var name = String(id || "").toLowerCase()
    if (/visualizer/.test(name)) return "visualizer"
    if (/weather/.test(name)) return "weather"
    if (/clock/.test(name)) return "clock"
    if (/calendar|date|agenda/.test(name)) return "calendar"
    if (/music|media|nowplaying/.test(name)) return "music"
    if (/photo|image/.test(name)) return "image"
    if (/note|quote/.test(name)) return "notes"
    if (/system|cpu|ram|temp|disk|battery|resource|uptime/.test(name)) return "system"
    return "other"
}

function key(row) { return row.id + ":" + (row.size || "compact") + ":" + (row.style || "plain") }

function entries() {
    var rows = WidgetLayout.registry().map(function(row) {
        return Object.assign({}, row, {size: "compact", style: row.category === "Nayori" ? "card" : "plain"})
    })
    // Retain the large-clock preset already offered by WidgetsPage.
    rows.splice(1, 0, {id: "clock", name: "Крупные часы", description: "Время и дата", category: "Nayori", icon: "◷", size: "large", style: "plain"})
    return rows
}

function groups(query, category) {
    var needle = String(query || "").trim().toLowerCase()
    var rows = entries()
    return TYPES.map(function(type) {
        var items = rows.filter(function(row) {
            return typeOf(row.id) === type.key && (!category || row.category === category)
                && (!needle || (row.name + " " + row.description + " " + row.category + " " + type.label).toLowerCase().indexOf(needle) >= 0)
        })
        return {key: type.key, label: type.label, items: items}
    }).filter(function(type) { return type.items.length > 0 })
}

function sets(query) {
    return WidgetLayout.categoryNames().map(function(category) {
        var types = groups(query, category)
        return {key: category, label: category, types: types,
            count: types.reduce(function(total, type) { return total + type.items.length }, 0)}
    }).filter(function(set) { return set.count > 0 })
}
