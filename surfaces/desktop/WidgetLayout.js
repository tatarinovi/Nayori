.pragma library
.import "ImportedWidgets.js" as ImportedWidgets

// Раскладка виджетов рабочего стола. Координаты — логические пиксели экрана.
// Шаг сетки — 12 логических пикселей, притяжение к краям — в пределах 12.
var GRID = 12

// The catalog and placement code share this registry. Rendering remains in the
// existing hosts so the wallpaper and input layers use identical components.
var REGISTRY = [
    { id: "clock", name: "Часы", description: "Время и дата", icon: "◷", category: "Nayori" },
    { id: "weather", name: "Погода", description: "Текущая погода и прогноз", icon: "☀", category: "Nayori" },
    { id: "music", name: "Музыка", description: "Управление проигрывателем", icon: "♫", category: "Nayori" },
    { id: "nowplaying", name: "Сейчас играет", description: "Обложка и текст песни", icon: "◉", category: "Nayori" },
    { id: "system", name: "Система", description: "Нагрузка и сеть", icon: "▥", category: "Nayori" },
    { id: "note", name: "Заметка", description: "Текст на рабочем столе", icon: "✎", category: "Nayori" }
]

function importedEntry(type, options) { return ImportedWidgets.selected(type, options) }
function isImported(type) { return importedEntry(type) !== null }
function registry() {
    return REGISTRY.concat(ImportedWidgets.entries.map(function(row) {
        return {id: row.type, name: row.name, description: row.category, icon: "◈", category: row.category}
    }))
}
function categoryNames() { return ["Nayori", "ii widgets", "Shima widgets", "Python widgets"] }
function catalog(query, category) {
    var needle = typeof query === "string" ? query.trim().toLowerCase() : ""
    return registry().filter(function(entry) {
        return (!category || category === entry.category) && (!needle || (entry.name + " " + entry.description + " " + entry.category).toLowerCase().indexOf(needle) >= 0)
    })
}

var BOX = {
    clock: { compact: [220, 100], large: [420, 154], extraLarge: [560, 200], huge: [700, 245] },
    weather: { compact: [248, 156], large: [340, 200] },
    music: { compact: [300, 152], large: [380, 184] },
    nowplaying: { compact: [520, 300], large: [680, 390] },
    system: { compact: [310, 204], large: [420, 298], extraLarge: [540, 388] },
    note: { compact: [260, 168], large: [340, 240] }
}

var STORM = [200, 386, 389, 392, 395]
var SNOW = [179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377]
var RAIN = [176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359]
var FOG = [143, 248, 260]
var MONTHS = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
var SCENE_LABEL = {
    clear: "Ясно",
    cloudy: "Облачно",
    rain: "Дождь",
    snow: "Снег",
    storm: "Гроза",
    fog: "Туман"
}

function gridSize() {
    return GRID
}

function isType(type) {
    return registry().some(function(entry) { return entry.id === type })
}

function outputNameOk(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 256 && !/[\x00-\x1f]/.test(name)
        && name !== "__proto__" && name !== "constructor" && name !== "prototype"
}

function cleanId(value) {
    if (typeof value !== "string")
        return ""
    var id = value.trim()
    if (!id || id.length > 80 || /[\x00-\x1f]/.test(id))
        return ""
    if (id === "__proto__" || id === "constructor" || id === "prototype")
        return ""
    return id
}

function uniqueId(used, preferred) {
    var id = cleanId(preferred)
    if (id && !used[id])
        return id
    var n = 1
    while (used["w" + n])
        n++
    return "w" + n
}

function coord(value) {
    if (typeof value === "number")
        return isFinite(value) ? Math.round(value) : 0
    if (typeof value === "string" && value.trim() !== "") {
        var parsed = Number(value)
        if (isFinite(parsed))
            return Math.round(parsed)
    }
    return 0
}

function extent(value) {
    var n = Number(value)
    if (!isFinite(n) || n <= 0)
        return 0
    return Math.floor(n)
}

function normalizeSize(type, size) {
    if ((type === "clock" && (size === "extraLarge" || size === "huge")) || (type === "system" && size === "extraLarge")) return size
    return size === "large" ? "large" : "compact"
}

function sizeOf(item) {
    var imported = item ? importedEntry(item.type, item.options) : null
    var type = item && (BOX[item.type] || imported) ? item.type : "note"
    var size = normalizeSize(type, item && item.size)
    var box = imported ? [imported.width, imported.height] : BOX[type][size]
    if (imported && size === "large") box = [box[0] * 1.5, box[1] * 1.5]
    var limits = sizeLimits(type, item && item.options)
    var result = {
        width: dimension(item && item.width, limits.minWidth, limits.maxWidth, box[0]),
        height: dimension(item && item.height, limits.minHeight, limits.maxHeight, box[1])
    }
    if (imported && imported.minAspect > 0 && result.width / result.height < imported.minAspect)
        result.width = Math.min(limits.maxWidth, Math.round(result.height * imported.minAspect))
    if (imported && imported.maxAspect > 0 && result.width / result.height > imported.maxAspect)
        result.height = Math.min(limits.maxHeight, Math.round(result.width / imported.maxAspect))
    return result
}

function sizeLimits(type, options) {
    var imported = importedEntry(type, options)
    if (imported) return {minWidth: imported.minWidth || 80, minHeight: imported.minHeight || 60, maxWidth: imported.maxWidth || 1800, maxHeight: imported.maxHeight || 1200}
    var variants = BOX[type] || BOX.note
    var smallest = variants.compact
    var maxWidth = smallest[0]
    var maxHeight = smallest[1]
    Object.keys(variants).forEach(function(key) {
        maxWidth = Math.max(maxWidth, variants[key][0])
        maxHeight = Math.max(maxHeight, variants[key][1])
    })
    return { minWidth: smallest[0], minHeight: smallest[1], maxWidth: maxWidth * 2, maxHeight: maxHeight * 2 }
}

function dimension(value, min, max, fallback) {
    if (typeof value !== "number" || !isFinite(value) || value <= 0) return fallback
    return Math.round(Math.max(min, Math.min(max, value)))
}

function copyOpacity(source, target) {
    if (typeof source.opacity === "number" && isFinite(source.opacity))
        target.opacity = Math.max(0.1, Math.min(1, source.opacity))
}

function copyDimensions(source, target) {
    var limits = sizeLimits(source.type, source.options)
    if (typeof source.width === "number" && isFinite(source.width) && source.width > 0)
        target.width = dimension(source.width, limits.minWidth, limits.maxWidth, limits.minWidth)
    if (typeof source.height === "number" && isFinite(source.height) && source.height > 0)
        target.height = dimension(source.height, limits.minHeight, limits.maxHeight, limits.minHeight)
}

function resize(items, id, width, height) {
    var list = normalizeItems(items)
    for (var i = 0; i < list.length; i++) {
        if (list[i].id !== id) continue
        var limits = sizeLimits(list[i].type, list[i].options)
        var current = sizeOf(list[i])
        list[i].width = dimension(width, limits.minWidth, limits.maxWidth, current.width)
        list[i].height = dimension(height, limits.minHeight, limits.maxHeight, current.height)
        break
    }
    return list
}

function normalizeMetrics(metrics) {
    var list = arrayValue(metrics)
    var result = []
    for (var i = 0; i < list.length; i++)
        if ((list[i] === "cpu" || list[i] === "memory" || list[i] === "gpu") && result.indexOf(list[i]) < 0)
            result.push(list[i])
    return result.length ? result : ["cpu", "memory", "gpu"]
}

// JSON-only, bounded instance settings; never retain functions or prototype keys.
function cleanOptions(value, depth) {
    depth = depth || 0
    if (depth > 8 || value === undefined) return null
    if (value === null || typeof value === "boolean") return value
    if (typeof value === "number") return isFinite(value) ? value : null
    if (typeof value === "string") return value.slice(0, 32768)
    if (typeof value !== "object") return null
    if (Array.isArray(value)) return value.slice(0, 512).map(function(v) { return cleanOptions(v, depth + 1) })
    var result = {}
    Object.keys(value).slice(0, 256).forEach(function(key) {
        if (key === "__proto__" || key === "constructor" || key === "prototype") return
        result[key] = cleanOptions(value[key], depth + 1)
    })
    return result
}
function instanceOptions(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return {}
    var result = cleanOptions(value)
    return JSON.stringify(result).length <= 65536 ? result : {}
}
function changeItem(items, id, field, value) {
    var list = normalizeItems(items)
    for (var i = 0; i < list.length; i++) {
        var item = list[i]
        if (item.id !== id) continue
        if (field === "size") { item.size = normalizeSize(item.type, value); delete item.width; delete item.height }
        if (field === "style") item.style = value === "plain" ? "plain" : "card"
        if (field === "opacity" && typeof value === "number" && isFinite(value)) item.opacity = Math.max(0.1, Math.min(1, value))
        if (field === "options" && isImported(item.type)) item.options = instanceOptions(value)
        if (field === "metrics" && item.type === "system") item.metrics = normalizeMetrics(value)
    }
    return list
}

function copyItem(item) {
    var source = item || {}
    var next = {
        id: typeof source.id === "string" ? source.id : "",
        type: source.type,
        x: typeof source.x === "number" && isFinite(source.x) ? source.x : coord(source.x),
        y: typeof source.y === "number" && isFinite(source.y) ? source.y : coord(source.y),
        size: normalizeSize(source.type, source.size),
        style: source.style === "plain" ? "plain" : "card"
    }
    if (isImported(source.type)) next.options = instanceOptions(source.options)
    copyDimensions(source, next)
    copyOpacity(source, next)
    if (source.type === "system")
        next.metrics = normalizeMetrics(source.metrics)
    if (source.type === "note")
        next.text = typeof source.text === "string" ? source.text : ""
    return next
}

// QML signals can expose a QVariantList as an array-like object rather than a JS Array.
function arrayValue(value) {
    if (Array.isArray(value)) return value
    if (!value || typeof value !== "object" || typeof value.length !== "number" ||
        !isFinite(value.length) || value.length < 0 || value.length > 10000 || Math.floor(value.length) !== value.length)
        return []
    var result = []
    for (var i = 0; i < value.length; i++) result.push(value[i])
    return result
}

function normalizeItems(list) {
    var next = []
    var used = {}
    var source = arrayValue(list)
    var i
    for (i = 0; i < source.length; i++) {
        var raw = source[i]
        if (!raw || typeof raw !== "object" || Array.isArray(raw) || !isType(raw.type))
            continue
        var item = {
            id: "",
            type: raw.type,
            x: coord(raw.x),
            y: coord(raw.y),
            size: normalizeSize(raw.type, raw.size),
            style: raw.style === "plain" ? "plain" : "card"
        }
        if (isImported(raw.type)) item.options = instanceOptions(raw.options)
        copyDimensions(raw, item)
        copyOpacity(raw, item)
        if (item.type === "system")
            item.metrics = normalizeMetrics(raw.metrics)
        if (item.type === "note")
            item.text = typeof raw.text === "string" ? raw.text : ""
        item.id = uniqueId(used, raw.id)
        used[item.id] = true
        next.push(item)
    }
    return next
}

function normalizeScreen(value) {
    var snap = true
    var items = []
    if (value && typeof value === "object" && !Array.isArray(value)) {
        if (value.snap === false)
            snap = false
        items = normalizeItems(value.items)
    }
    return { snap: snap, items: items }
}

function normalize(document) {
    var result = {}
    if (!document || typeof document !== "object" || Array.isArray(document))
        return result
    var names = Object.keys(document)
    var i
    for (i = 0; i < names.length; i++) {
        var name = names[i]
        if (!outputNameOk(name))
            continue
        result[name] = normalizeScreen(document[name])
    }
    return result
}

function clamp(items, screenW, screenH) {
    var w = extent(screenW)
    var h = extent(screenH)
    var list = arrayValue(items)
    var next = []
    var i
    for (i = 0; i < list.length; i++) {
        if (!list[i] || typeof list[i] !== "object" || Array.isArray(list[i]))
            continue
        var item = copyItem(list[i])
        var box = sizeOf(item)
        var maxX = Math.max(0, w - box.width)
        var maxY = Math.max(0, h - box.height)
        var x = typeof item.x === "number" && isFinite(item.x) ? item.x : 0
        var y = typeof item.y === "number" && isFinite(item.y) ? item.y : 0
        item.x = Math.min(maxX, Math.max(0, x))
        item.y = Math.min(maxY, Math.max(0, y))
        next.push(item)
    }
    return next
}

function snapTo(value, grid) {
    var g = Number(grid)
    if (!isFinite(g) || g <= 0)
        g = GRID
    var n = Number(value)
    if (!isFinite(n))
        n = 0
    return Math.round(n / g) * g
}

// Edge attraction applies after grid snapping so the far edge remains reachable.
function snapEdges(x, y, box, screenW, screenH, threshold) {
    var limit = threshold === undefined ? 12 : Math.max(0, Number(threshold) || 0)
    var maxX = Math.max(0, extent(screenW) - box.width)
    var maxY = Math.max(0, extent(screenH) - box.height)
    return {
        x: Math.abs(x) <= limit ? 0 : Math.abs(x - maxX) <= limit ? maxX : x,
        y: Math.abs(y) <= limit ? 0 : Math.abs(y - maxY) <= limit ? maxY : y
    }
}

// Use the same projection for the live drag and the saved placement. Applying
// it twice must preserve screen edges even when they are between grid lines.
function placementPosition(x, y, box, screenW, screenH, snap) {
    function axis(value, screenExtent, size) {
        var max = Math.max(0, extent(screenExtent) - size)
        var number = Number(value)
        var bounded = Math.max(0, Math.min(max, isFinite(number) ? Math.round(number) : 0))
        if (snap !== true) return bounded
        if (bounded <= 12) return 0
        if (max - bounded <= 12) return max
        var aligned = Math.max(0, Math.min(max, snapTo(bounded)))
        if (aligned <= 12) return 0
        if (max - aligned <= 12) return max
        return aligned
    }
    return {x: axis(x, screenW, box.width), y: axis(y, screenH, box.height)}
}

function move(items, id, x, y, snap, grid) {
    var list = arrayValue(items)
    var next = []
    var i
    for (i = 0; i < list.length; i++) {
        if (!list[i] || typeof list[i] !== "object")
            continue
        var item = copyItem(list[i])
        if (item.id === id) {
            var px = coord(x)
            var py = coord(y)
            if (typeof x === "number" && isFinite(x))
                px = x
            if (typeof y === "number" && isFinite(y))
                py = y
            if (snap === true) {
                px = snapTo(px, grid)
                py = snapTo(py, grid)
            } else {
                px = Math.round(px)
                py = Math.round(py)
            }
            item.x = px
            item.y = py
        }
        next.push(item)
    }
    return next
}

function add(items, spec, screenW, screenH) {
    var list = normalizeItems(items)
    if (!spec || typeof spec !== "object" || !isType(spec.type))
        return list
    var used = {}
    var i
    for (i = 0; i < list.length; i++)
        used[list[i].id] = true
    var index = list.length
    var item = {
        id: uniqueId(used, spec.id),
        type: spec.type,
        x: spec.x === undefined || spec.x === null ? 24 + (index % 8) * GRID : coord(spec.x),
        y: spec.y === undefined || spec.y === null ? 24 + (index % 8) * GRID : coord(spec.y),
        size: normalizeSize(spec.type, spec.size),
        style: spec.style === "plain" ? "plain" : "card"
    }
    if (isImported(item.type)) { item.options = instanceOptions(spec.options); if (spec.style === undefined) item.style = "plain" }
    if (item.type === "system")
        item.metrics = normalizeMetrics(spec.metrics)
    if (item.type === "note")
        item.text = typeof spec.text === "string" ? spec.text : ""
    list.push(item)
    if (arguments.length >= 4)
        return clampMoved(list, item.id, screenW, screenH)
    return list
}

function remove(items, id) {
    var list = arrayValue(items)
    var next = []
    var i
    for (i = 0; i < list.length; i++) {
        if (!list[i] || typeof list[i] !== "object" || list[i].id === id)
            continue
        next.push(copyItem(list[i]))
    }
    return next
}

function editText(items, id, text) {
    var list = arrayValue(items)
    var value = typeof text === "string" ? text : ""
    var next = []
    var i
    for (i = 0; i < list.length; i++) {
        if (!list[i] || typeof list[i] !== "object")
            continue
        var item = copyItem(list[i])
        if (item.id === id && item.type === "note")
            item.text = value
        next.push(item)
    }
    return next
}

function clampMoved(items, id, screenW, screenH) {
    var placed = null
    var i
    for (i = 0; i < items.length; i++) {
        if (items[i].id === id)
            placed = clamp([items[i]], screenW, screenH)[0]
    }
    if (!placed)
        return items.slice()
    var next = []
    for (i = 0; i < items.length; i++)
        next.push(items[i].id === id ? placed : items[i])
    return next
}

// An external edit invalidates snapshots; otherwise undo could erase it.
function incomingDisposition(incoming, pending, previous) {
    var next = normalizeScreen(incoming)
    if (pending && sameLayout(next, pending)) return "ack"
    if (pending || (previous && !sameLayout(next, previous))) return "external"
    return "unchanged"
}

function sameIds(a, b) {
    if (!a || !b || a.length !== b.length)
        return false
    var i
    for (i = 0; i < a.length; i++) {
        if (!a[i] || !b[i] || a[i].id !== b[i].id)
            return false
    }
    return true
}

function sameLayout(a, b) {
    if (!a || !b || typeof a !== "object" || typeof b !== "object")
        return false
    if ((a.snap === true) !== (b.snap === true))
        return false
    var ai = a.items || []
    var bi = b.items || []
    if (ai.length !== bi.length)
        return false
    var i
    for (i = 0; i < ai.length; i++) {
        var left = ai[i] || {}
        var right = bi[i] || {}
        if (isImported(left.type) && JSON.stringify(instanceOptions(left.options)) !== JSON.stringify(instanceOptions(right.options))) return false
        if (left.id !== right.id || left.type !== right.type || left.x !== right.x || left.y !== right.y)
            return false
        if (normalizeSize(left.type, left.size) !== normalizeSize(right.type, right.size))
            return false
        var leftOpacity = typeof left.opacity === "number" && isFinite(left.opacity) ? Math.max(0.1, Math.min(1, left.opacity)) : 1
        var rightOpacity = typeof right.opacity === "number" && isFinite(right.opacity) ? Math.max(0.1, Math.min(1, right.opacity)) : 1
        if (leftOpacity !== rightOpacity) return false
        var leftBox = sizeOf(left), rightBox = sizeOf(right)
        if (leftBox.width !== rightBox.width || leftBox.height !== rightBox.height)
            return false
        if ((left.style === "plain" ? "plain" : "card") !== (right.style === "plain" ? "plain" : "card"))
            return false
        if (left.type === "system" && normalizeMetrics(left.metrics).join(",") !== normalizeMetrics(right.metrics).join(","))
            return false
        if ((left.text || "") !== (right.text || ""))
            return false
    }
    return true
}

function readNumber(value) {
    if (typeof value === "number")
        return isFinite(value) ? value : null
    if (typeof value === "string" && value.trim() !== "") {
        var parsed = Number(value)
        if (isFinite(parsed))
            return parsed
    }
    return null
}

function textField(field) {
    if (typeof field === "string" && field.trim())
        return field.trim()
    if (Array.isArray(field) && field[0]) {
        if (typeof field[0] === "string" && field[0].trim())
            return field[0].trim()
        if (field[0] && typeof field[0].value === "string" && field[0].value.trim())
            return field[0].value.trim()
    }
    return ""
}

function weatherScene(code) {
    if (code === null || code === undefined || code === "") return ""
    var n = typeof code === "number" ? code : Number(code)
    if (!isFinite(n))
        return ""
    if (STORM.indexOf(n) >= 0)
        return "storm"
    if (SNOW.indexOf(n) >= 0)
        return "snow"
    if (RAIN.indexOf(n) >= 0)
        return "rain"
    if (FOG.indexOf(n) >= 0)
        return "fog"
    if (n === 113)
        return "clear"
    return "cloudy"
}

function forecastLabel(iso) {
    var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "")
    if (!match)
        return ""
    var year = Number(match[1])
    var month = Number(match[2])
    var day = Number(match[3])
    if (month < 1 || month > 12 || day < 1 || day > 31)
        return ""
    var probe = new Date(Date.UTC(year, month - 1, day))
    if (probe.getUTCFullYear() !== year || probe.getUTCMonth() !== month - 1 || probe.getUTCDate() !== day)
        return ""
    return day + "\u00A0" + MONTHS[month - 1]
}

function temperatureText(value) {
    if (typeof value !== "number" || !isFinite(value))
        return ""
    var rounded = Math.round(value)
    var body = Math.abs(rounded) + "°"
    return rounded < 0 ? "\u2212" + body : body
}

function currentOf(data) {
    if (!data || typeof data !== "object" || Array.isArray(data))
        return null
    if (Array.isArray(data.current_condition) && data.current_condition[0] && typeof data.current_condition[0] === "object")
        return data.current_condition[0]
    if (data.temp_C !== undefined || data.FeelsLikeC !== undefined || data.weatherCode !== undefined || data.weatherDesc !== undefined || data.lang_ru !== undefined)
        return data
    return null
}

function readWeather(data) {
    var current = currentOf(data)
    var temperature = current ? readNumber(current.temp_C) : null
    var feelsLike = current ? readNumber(current.FeelsLikeC) : null
    var weatherCode = current ? readNumber(current.weatherCode) : null
    var scene = weatherScene(weatherCode)
    var description = ""
    if (current) {
        description = textField(current.lang_ru)
        if (!description && scene)
            description = SCENE_LABEL[scene] || ""
        if (!description)
            description = textField(current.weatherDesc)
    }
    var humidity = current ? readNumber(current.humidity) : null
    if (humidity === null || humidity < 0 || humidity > 100)
        humidity = null
    else
        humidity = Math.round(humidity)
    var forecast = []
    var days = data && typeof data === "object" && Array.isArray(data.weather) ? data.weather : []
    var i
    for (i = 0; i < days.length && forecast.length < 3; i++) {
        var day = days[i]
        if (!day || typeof day !== "object")
            continue
        if (/^\d{4}-\d{2}-\d{2}$/.test(day.date || "") && !forecastLabel(day.date))
            continue
        var max = readNumber(day.maxtempC)
        var min = readNumber(day.mintempC)
        if (max === null && min === null)
            continue
        forecast.push({
            label: forecastLabel(day.date),
            max: max,
            min: min
        })
    }
    if (!current && !forecast.length)
        return null
    if (temperature === null && feelsLike === null && weatherCode === null && !description && humidity === null && !forecast.length)
        return null
    return {
        temperature: temperature,
        feelsLike: feelsLike,
        weatherCode: weatherCode,
        description: description,
        humidity: humidity,
        forecast: forecast
    }
}

function readCpuCounters(text) {
    if (typeof text !== "string" || !text)
        return null
    var fields = text.split("\n")[0].trim().split(/\s+/)
    if (fields.length < 9 || fields[0] !== "cpu")
        return null
    var total = 0
    var i
    for (i = 1; i <= 8; i++) {
        var value = Number(fields[i])
        if (!isFinite(value) || value < 0)
            return null
        total += value
    }
    var idle = Number(fields[4]) + Number(fields[5])
    if (!isFinite(idle) || idle < 0)
        return null
    return { total: total, idle: idle }
}

function cpuLoad(previous, next) {
    if (!previous || !next)
        return null
    var elapsed = next.total - previous.total
    var idleElapsed = next.idle - previous.idle
    if (!(elapsed > 0) || idleElapsed < 0 || idleElapsed > elapsed)
        return null
    return Math.max(0, Math.min(1, 1 - idleElapsed / elapsed))
}

function readCpuInfo(text) {
    if (typeof text !== "string" || !text) return null
    var total = 0
    var samples = 0
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var match = /^cpu MHz\s*:\s*(\d+(?:\.\d+)?)\s*$/i.exec(lines[i])
        if (!match) continue
        var mhz = Number(match[1])
        if (isFinite(mhz) && mhz > 0) { total += mhz; samples++ }
    }
    return samples ? { mhz: total / samples } : null
}

function cpuDetails(sample) {
    if (!sample || typeof sample.mhz !== "number" || !isFinite(sample.mhz) || sample.mhz <= 0)
        return ""
    return (sample.mhz / 1000).toFixed(1) + " GHz"
}

function readMeminfo(text) {
    if (typeof text !== "string" || !text)
        return null
    var total = null
    var available = null
    var lines = text.split("\n")
    var i
    for (i = 0; i < lines.length; i++) {
        var match = /^(MemTotal|MemAvailable):\s+(\d+)\s+kB\s*$/.exec(lines[i])
        if (!match)
            continue
        var value = Number(match[2])
        if (!isFinite(value) || value < 0)
            return null
        if (match[1] === "MemTotal")
            total = value
        else
            available = value
    }
    if (total === null || available === null || total <= 0 || available > total)
        return null
    return {
        totalKb: total,
        availableKb: available,
        used: (total - available) / total
    }
}

function memoryAmount(usedKb, totalKb) {
    if (typeof usedKb !== "number" || typeof totalKb !== "number" || !isFinite(usedKb) || !isFinite(totalKb)
            || usedKb < 0 || totalKb <= 0 || usedKb > totalKb)
        return ""
    var totalBytes = totalKb * 1024
    var unit = totalBytes >= 1000000000 ? 1000000000 : 1000000
    var suffix = unit === 1000000000 ? "GB" : "MB"
    return (usedKb * 1024 / unit).toFixed(1) + " / " + (totalBytes / unit).toFixed(1) + " " + suffix
}

function percentLabel(fraction) {
    if (typeof fraction !== "number" || !isFinite(fraction) || fraction < 0 || fraction > 1)
        return ""
    return Math.round(fraction * 100) + "%"
}

function batteryPercent(value) {
    if (typeof value !== "number" || !isFinite(value) || value < 0)
        return ""
    if (value <= 1)
        return Math.round(value * 100) + "%"
    if (value <= 100)
        return Math.round(value) + "%"
    return ""
}
