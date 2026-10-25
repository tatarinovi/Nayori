pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Загрузка ярлыков и единственная оценка строки.
// Запуск только через DesktopEntry.execute(), без разбора Exec.
QtObject {
    id: root

    property string query: ""
    property int generation: 0
    property bool catalogReady: false

    readonly property int resultLimit: 5

    // Стволы .desktop, которые на этой машине есть в меню.
    // Нет ярлыка или стоит NoDisplay — карточки не будет.
    readonly property var favoriteIds: [
        "firefox",
        "kitty",
        "org.gnome.Nautilus",
        "dev.zed.Zed",
        "org.telegram.desktop"
    ]

    readonly property string normalizedQuery: root.query.trim().toLocaleLowerCase()
    readonly property int applicationCount: root.countApplications(root.generation)
    readonly property var favorites: root.collectFavorites(root.generation)
    readonly property var results: root.collectResults(root.normalizedQuery, root.generation)

    // QtObject не принимает дочерние Connections. Каталог слушаем с объекта.
    function bump() {
        root.generation += 1
    }

    function watchCatalog() {
        try {
            if (typeof DesktopEntries === "undefined" || !DesktopEntries)
                return
            DesktopEntries.applicationsChanged.connect(root.bump)
            if (DesktopEntries.applications)
                DesktopEntries.applications.valuesChanged.connect(root.bump)
        } catch (error) {
            return
        }
    }

    function unwatchCatalog() {
        try {
            if (typeof DesktopEntries === "undefined" || !DesktopEntries)
                return
            DesktopEntries.applicationsChanged.disconnect(root.bump)
            if (DesktopEntries.applications)
                DesktopEntries.applications.valuesChanged.disconnect(root.bump)
        } catch (error) {
            return
        }
    }

    Component.onCompleted: {
        root.watchCatalog()
        Qt.callLater(function() {
            root.bump()
            root.catalogReady = true
        })
    }

    Component.onDestruction: root.unwatchCatalog()

    function fold(value) {
        if (value === undefined || value === null)
            return ""
        return String(value).trim().toLocaleLowerCase()
    }

    function byId(desktopId) {
        try {
            if (typeof DesktopEntries === "undefined" || !DesktopEntries)
                return null
            return DesktopEntries.byId(desktopId)
        } catch (error) {
            return null
        }
    }

    function usable(entry) {
        if (!entry || entry.noDisplay === true)
            return false
        const name = entry.name === undefined || entry.name === null ? "" : String(entry.name).trim()
        const id = entry.id === undefined || entry.id === null ? "" : String(entry.id).trim()
        return name.length > 0 && id.length > 0
    }

    // Точный id, с суффиксом .desktop и без. Регистр сохраняется.
    // Похожее имя через heuristicLookup не подставляется.
    function lookup(desktopId) {
        const raw = desktopId === undefined || desktopId === null ? "" : String(desktopId).trim()
        if (raw.length === 0)
            return null
        const candidates = [raw]
        if (raw.toLocaleLowerCase().endsWith(".desktop"))
            candidates.push(raw.slice(0, raw.length - 8))
        else
            candidates.push(raw + ".desktop")

        const seen = {}
        for (let i = 0; i < candidates.length; i++) {
            const candidate = candidates[i]
            if (!candidate || seen[candidate])
                continue
            seen[candidate] = true
            const entry = root.byId(candidate)
            if (root.usable(entry))
                return entry
        }
        return null
    }

    // true, если процесс отдан ярлыку. Пустая строка — запускать нечего.
    function launch(desktopId) {
        const entry = root.lookup(desktopId)
        if (!entry)
            return ""
        try {
            entry.execute()
        } catch (error) {
            return ""
        }
        return String(entry.id).trim()
    }

    function iconSource(icon) {
        const name = icon === undefined || icon === null ? "" : String(icon).trim()
        if (name.length === 0)
            return ""
        if (name.charAt(0) === "/" || name.startsWith("file:"))
            return name
        try {
            if (!Quickshell.hasThemeIcon(name))
                return ""
            const path = Quickshell.iconPath(name)
            return path ? String(path) : ""
        } catch (error) {
            return ""
        }
    }

    function cardFor(entry) {
        if (!root.usable(entry))
            return null
        const generic = entry.genericName === undefined || entry.genericName === null
                ? ""
                : String(entry.genericName).trim()
        return {
            id: String(entry.id).trim(),
            name: String(entry.name).trim(),
            genericName: generic,
            iconSource: root.iconSource(entry.icon)
        }
    }

    function applicationList() {
        let values = null
        try {
            const model = DesktopEntries.applications
            values = model ? model.values : null
        } catch (error) {
            return []
        }
        if (!values || typeof values.length !== "number")
            return []
        const list = []
        for (let i = 0; i < values.length; i++) {
            const entry = values[i]
            if (root.usable(entry))
                list.push(entry)
        }
        return list
    }

    function stringList(value) {
        if (!value || typeof value.length !== "number")
            return []
        const list = []
        for (let i = 0; i < value.length; i++)
            list.push(value[i])
        return list
    }

    // 0 точное, 1 префикс, 2 вхождение, 3 нет.
    function fieldRank(value, foldedQuery) {
        const text = root.fold(value)
        const needle = root.fold(foldedQuery)
        if (needle.length === 0 || text.length === 0)
            return 3
        if (text === needle)
            return 0
        if (text.startsWith(needle))
            return 1
        if (text.indexOf(needle) !== -1)
            return 2
        return 3
    }

    // Имя выше остальных полей: точное имя важнее точного id.
    function entryRank(entry, foldedQuery) {
        const nameRank = root.fieldRank(entry.name, foldedQuery)
        if (nameRank < 3)
            return nameRank

        const fields = []
        if (entry.genericName)
            fields.push(entry.genericName)
        if (entry.comment)
            fields.push(entry.comment)
        if (entry.id) {
            fields.push(entry.id)
            const id = String(entry.id)
            if (id.endsWith(".desktop"))
                fields.push(id.slice(0, id.length - 8))
        }
        const keywords = root.stringList(entry.keywords)
        for (let i = 0; i < keywords.length; i++)
            fields.push(keywords[i])

        let best = 3
        for (let j = 0; j < fields.length; j++) {
            const rank = root.fieldRank(fields[j], foldedQuery)
            if (rank < best)
                best = rank
        }
        if (best >= 3)
            return 6
        return 3 + best
    }

    function collectFavorites(generation) {
        if (generation < 0)
            return []
        const ids = root.favoriteIds
        if (!ids || typeof ids.length !== "number")
            return []
        const cards = []
        const seen = {}
        for (let i = 0; i < ids.length; i++) {
            const entry = root.lookup(ids[i])
            if (!entry)
                continue
            const id = String(entry.id).trim()
            if (seen[id])
                continue
            seen[id] = true
            const card = root.cardFor(entry)
            if (card)
                cards.push(card)
        }
        return cards
    }

    function countApplications(generation) {
        if (generation < 0)
            return 0
        return root.applicationList().length
    }

    // Пустой запрос не показывает «первые по алфавиту»: до ввода живы только избранные.
    function collectResults(foldedQuery, generation) {
        if (generation < 0 || foldedQuery.length === 0)
            return []
        const apps = root.applicationList()
        const matched = []
        const seen = {}
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i]
            const id = String(entry.id).trim()
            if (seen[id])
                continue
            const rank = root.entryRank(entry, foldedQuery)
            if (rank > 5)
                continue
            seen[id] = true
            matched.push({
                entry: entry,
                rank: rank,
                name: String(entry.name),
                id: id
            })
        }

        matched.sort(function(a, b) {
            if (a.rank !== b.rank)
                return a.rank - b.rank
            const left = root.fold(a.name)
            const right = root.fold(b.name)
            if (left < right)
                return -1
            if (left > right)
                return 1
            if (a.id < b.id)
                return -1
            if (a.id > b.id)
                return 1
            return 0
        })

        const cards = []
        const limit = Math.min(root.resultLimit, matched.length)
        for (let j = 0; j < limit; j++) {
            const card = root.cardFor(matched[j].entry)
            if (card)
                cards.push(card)
        }
        return cards
    }
}
