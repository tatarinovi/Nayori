.pragma library

// Сборка строк, выбор с клавиатуры и подписи. Обход файлов и разбор argv — в search_model.py.
// Списки и reconcile/move/pin держатся в том же порядке, что и Python-модель.

var TYPE_LABEL = {
    application: "приложение",
    file: "файл",
    folder: "папка",
    command: "команда",
    web: "интернет"
}

var SECTION = {
    application: "Приложения",
    files: "Файлы",
    command: "Команда"
}

var COPY = {
    scope: "Домашняя папка и каталоги XDG, без корня диска",
    searching: "Ищем в\u00a0домашней папке и каталогах XDG",
    short: "Файлы — от двух символов, в\u00a0домашней папке и каталогах XDG",
    truncated: "Показана только часть совпадений",
    error: "Не удалось просмотреть файлы. Приложения и поиск в\u00a0интернете доступны",
    commandWait: "Проверяем аргументы",
    commandReady: "Без оболочки",
    commandFailed: "Не удалось разобрать команду. Измените запрос",
    commandShell: "Конвейер и перенаправление не выполняются",
    commandQuote: "В команде не закрыта кавычка",
    commandLong: "Команда слишком длинная",
    commandEmpty: "После > укажите программу и аргументы",
    empty: "Ничего не нашлось",
    webTitle: "Поиск в\u00a0интернете",
    webSubtitle: "Искать в\u00a0Google"
}

var SHELLS = {
    sh: true, bash: true, zsh: true, dash: true, fish: true, ksh: true, csh: true, tcsh: true
}

function copy(key) {
    return COPY[key] || ""
}

function normalize(text) {
    return String(text === undefined || text === null ? "" : text).trim().replace(/\s+/g, " ")
}

function isCommandQuery(text) {
    return String(text === undefined || text === null ? "" : text).trim().charAt(0) === ">"
}

function commandBody(text) {
    var raw = String(text === undefined || text === null ? "" : text).trim()
    if (raw.charAt(0) !== ">")
        return ""
    return raw.slice(1).trim()
}

function fileNeedle(text) {
    if (isCommandQuery(text))
        return ""
    return normalize(text)
}

function webTerms(text) {
    var raw = normalize(text)
    if (!raw || isCommandQuery(raw))
        return ""
    var folded = raw.toLocaleLowerCase()
    if (folded === "web")
        return ""
    if (folded.indexOf("web ") === 0)
        return raw.slice(4).trim()
    return raw
}

function searchUrl(terms) {
    var text = String(terms === undefined || terms === null ? "" : terms).trim()
    if (!text)
        return ""
    return "https://www.google.com/search?q=" + encodeURIComponent(text)
}

function fileUrl(path) {
    var text = String(path === undefined || path === null ? "" : path)
    if (text.charAt(0) !== "/")
        return ""
    return "file://" + encodeURI(text).replace(/#/g, "%23").replace(/\?/g, "%3F")
}

function resultIsCurrent(current, payload) {
    if (!payload || typeof payload !== "object")
        return false
    return payload.generation === current && current > 0
}

function asList(value) {
    if (!value || typeof value.length !== "number")
        return []
    var list = []
    for (var i = 0; i < value.length; i++)
        list.push(value[i])
    return list
}

function safePath(path) {
    var text = String(path === undefined || path === null ? "" : path)
    if (text.charAt(0) !== "/" || text === "/" || text.indexOf("//") === 0)
        return false
    if (text.indexOf("\u0000") >= 0 || text.indexOf("\n") >= 0 || text.indexOf("\r") >= 0)
        return false
    return true
}

function commandMessage(code) {
    if (code === "shell")
        return COPY.commandShell
    if (code === "quote")
        return COPY.commandQuote
    if (code === "long")
        return COPY.commandLong
    return ""
}

function statusLine(state) {
    var input = state || {}
    if (input.commandMode)
        return input.commandBody ? "" : COPY.commandEmpty
    if (!input.searching)
        return ""
    if (input.status === "error")
        return COPY.error
    if (input.status === "loading")
        return COPY.searching
    if (input.truncated)
        return COPY.truncated
    if ((input.fileQueryLength || 0) < 2)
        return COPY.short
    return COPY.scope
}

function buildRows(spec) {
    var input = spec || {}
    var command = commandBody(input.query || "")
    var rows = []
    if (!command) {
        var apps = asList(input.apps)
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]
            if (!app)
                continue
            var name = String(app.name || "").trim()
            var ident = String(app.id || "").trim()
            if (!name || !ident)
                continue
            var generic = String(app.genericName || "").trim()
            if (generic.toLocaleLowerCase() === name.toLocaleLowerCase())
                generic = ""
            rows.push({
                kind: "application",
                key: "application:" + ident,
                id: ident,
                title: name,
                subtitle: generic,
                typeLabel: TYPE_LABEL.application,
                glyph: "",
                iconSource: String(app.iconSource || ""),
                path: "",
                argv: [],
                ok: false,
                pending: false,
                url: "",
                distinct: false
            })
        }
        var files = asList(input.files)
        for (var f = 0; f < files.length; f++) {
            var item = files[f]
            if (!item || (item.kind !== "file" && item.kind !== "folder"))
                continue
            var path = String(item.path || "")
            var fileName = String(item.name || "").trim()
            if (!fileName || !safePath(path))
                continue
            rows.push({
                kind: item.kind,
                key: item.kind + ":" + path,
                id: path,
                title: fileName,
                subtitle: String(item.directory || ""),
                typeLabel: TYPE_LABEL[item.kind],
                glyph: item.kind === "folder" ? "folder" : "file",
                iconSource: "",
                path: path,
                argv: [],
                ok: false,
                pending: false,
                url: "",
                distinct: false
            })
        }
    }
    if (command) {
        var given = asList(input.commandArgv)
        var argv = []
        for (var a = 0; a < given.length; a++) {
            if (typeof given[a] === "string")
                argv.push(given[a])
        }
        var code = String(input.commandCode || "")
        var failed = input.commandStatus === "error"
        var ok = input.commandOk === true && argv.length > 0 && !code && !failed
        var pending = input.commandPending === true && !code && !failed
        var message = commandMessage(code)
        rows.push({
            kind: "command",
            key: "command:" + command,
            id: "",
            title: command,
            subtitle: message || (failed ? COPY.commandFailed : (pending || !ok ? COPY.commandWait : COPY.commandReady)),
            typeLabel: TYPE_LABEL.command,
            glyph: "command",
            iconSource: "",
            path: "",
            argv: ok ? argv : [],
            ok: ok,
            pending: pending,
            url: "",
            distinct: true
        })
    }
    var terms = command ? "" : String(input.webTerms || "")
    var url = command ? "" : String(input.webUrl || "")
    if (terms && url) {
        rows.push({
            kind: "web",
            key: "web:" + terms,
            id: "",
            title: COPY.webTitle,
            subtitle: COPY.webSubtitle,
            typeLabel: TYPE_LABEL.web,
            glyph: "search",
            iconSource: "",
            path: "",
            argv: [],
            ok: false,
            pending: false,
            url: url,
            distinct: false
        })
    }
    var seen = {}
    for (var r = 0; r < rows.length; r++) {
        var group = rows[r].kind === "file" || rows[r].kind === "folder" ? "files" : rows[r].kind
        if (SECTION[group] && !seen[group]) {
            seen[group] = true
            rows[r].section = SECTION[group]
        } else {
            rows[r].section = ""
        }
    }
    return rows
}

function reconcile(rows, index, key, pinned) {
    var list = asList(rows)
    if (!list.length)
        return {index: 0, key: "", pinned: false}
    if (pinned && key) {
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].key === key)
                return {index: i, key: key, pinned: true}
        }
        var clamped = Math.max(0, Math.min(Number(index) || 0, list.length - 1))
        return {index: clamped, key: list[clamped].key || "", pinned: true}
    }
    return {index: 0, key: list[0].key || "", pinned: false}
}

function move(rows, index, delta) {
    var list = asList(rows)
    if (!list.length)
        return {index: 0, key: "", pinned: false}
    var next = (Number(index) || 0) + (Number(delta) || 0)
    if (next < 0)
        next = 0
    if (next >= list.length)
        next = list.length - 1
    return {index: next, key: list[next].key || "", pinned: true}
}

function pinAt(rows, index) {
    var list = asList(rows)
    var position = Number(index)
    if (!list.length || position < 0 || position >= list.length)
        return {index: 0, key: "", pinned: false}
    return {index: position, key: list[position].key || "", pinned: true}
}

function shellName(program) {
    var text = String(program || "").replace(/\\/g, "/")
    var parts = text.split("/")
    return parts[parts.length - 1]
}

function activationPlan(row) {
    if (!row)
        return {action: "none"}
    if (row.kind === "application") {
        var ident = String(row.id || "").trim()
        if (!ident)
            return {action: "none"}
        return {action: "desktop", id: ident}
    }
    if (row.kind === "file" || row.kind === "folder") {
        var path = String(row.path || "")
        if (!safePath(path))
            return {action: "none"}
        return {action: "argv", argv: ["xdg-open", path]}
    }
    if (row.kind === "command") {
        if (row.pending)
            return {action: "wait"}
        if (row.ok !== true)
            return {action: "none"}
        var argv = asList(row.argv)
        var cleaned = []
        for (var i = 0; i < argv.length; i++) {
            if (typeof argv[i] !== "string" || argv[i].indexOf("\u0000") >= 0)
                return {action: "none"}
            cleaned.push(argv[i])
        }
        if (!cleaned.length || !cleaned[0])
            return {action: "none"}
        if (cleaned.length >= 2 && SHELLS[shellName(cleaned[0])] && (cleaned[1] === "-c" || cleaned[1] === "-lc"))
            return {action: "none"}
        return {action: "argv", argv: cleaned}
    }
    if (row.kind === "web") {
        var url = String(row.url || "")
        if (url.indexOf("https://www.google.com/search?q=") !== 0)
            return {action: "none"}
        return {action: "url", url: url, fallback: ["xdg-open", url]}
    }
    return {action: "none"}
}
