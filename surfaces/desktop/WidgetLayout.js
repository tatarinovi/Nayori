.pragma library

// Раскладка виджетов рабочего стола. Координаты — логические пиксели экрана.
// Сетка 24. При snap позиция округляется к ближайшей линии: до линии не больше
// половины шага (12), поэтому порог совпадает с обычным округлением.
var GRID = 24

var TYPES = { clock: true, weather: true, music: true, system: true, note: true }

var BOX = {
    clock: { compact: [220, 96], large: [420, 176] },
    weather: { compact: [248, 156], large: [340, 228] },
    music: { compact: [300, 132], large: [380, 180] },
    system: { compact: [236, 168], large: [300, 216] },
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
    return typeof type === "string" && TYPES[type] === true
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

function sizeOf(item) {
    var type = item && BOX[item.type] ? item.type : "note"
    var size = item && item.size === "large" ? "large" : "compact"
    var box = BOX[type][size]
    return { width: box[0], height: box[1] }
}

function copyItem(item) {
    var source = item || {}
    var next = {
        id: typeof source.id === "string" ? source.id : "",
        type: source.type,
        x: typeof source.x === "number" && isFinite(source.x) ? source.x : coord(source.x),
        y: typeof source.y === "number" && isFinite(source.y) ? source.y : coord(source.y),
        size: source.size === "large" ? "large" : "compact",
        style: source.style === "plain" ? "plain" : "card"
    }
    if (source.type === "note")
        next.text = typeof source.text === "string" ? source.text : ""
    return next
}

function normalizeItems(list) {
    var next = []
    var used = {}
    var source = Array.isArray(list) ? list : []
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
            size: raw.size === "large" ? "large" : "compact",
            style: raw.style === "plain" ? "plain" : "card"
        }
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
    var list = Array.isArray(items) ? items : []
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

function move(items, id, x, y, snap, grid) {
    var list = Array.isArray(items) ? items : []
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
        size: spec.size === "large" ? "large" : "compact",
        style: spec.style === "plain" ? "plain" : "card"
    }
    if (item.type === "note")
        item.text = typeof spec.text === "string" ? spec.text : ""
    list.push(item)
    if (arguments.length >= 4)
        return clampMoved(list, item.id, screenW, screenH)
    return list
}

function remove(items, id) {
    var list = Array.isArray(items) ? items : []
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
    var list = Array.isArray(items) ? items : []
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
        if (left.id !== right.id || left.type !== right.type || left.x !== right.x || left.y !== right.y)
            return false
        if ((left.size === "large" ? "large" : "compact") !== (right.size === "large" ? "large" : "compact"))
            return false
        if ((left.style === "plain" ? "plain" : "card") !== (right.style === "plain" ? "plain" : "card"))
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
