pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services/niri"

// Остров открытых окон. Без PanelWindow: размер из содержимого,
// хром как у центрального острова в shell.qml.
Rectangle {
    id: root

    required property var tokens
    property string outputName: ""

    readonly property int pad: tokens.spacing.small
    readonly property int slot: tokens.spacing.large
    readonly property int gap: tokens.spacing.small
    // Одна строка внутри высоты острова (slot + pad * 2 = 40).
    // Пять знаков — ширина нынешней заглушки без метки лаунчера.
    readonly property int maxVisible: 5

    property int desktopEpoch: 0

    readonly property bool niriUp: {
        try {
            return typeof Niri !== "undefined" && !!Niri && Niri.available === true
        } catch (error) {
            return false
        }
    }

    readonly property var windowView: {
        try {
            if (!root.niriUp)
                return { windows: [], overflow: 0 }
            let output = root.outputName
            if (output.length === 0)
                output = Niri.focusedOutput ? String(Niri.focusedOutput) : ""
            return root.collect(output, Niri.workspaces, Niri.windows)
        } catch (error) {
            return { windows: [], overflow: 0 }
        }
    }

    readonly property var visibleWindows: {
        const view = root.windowView
        if (!view || !view.windows)
            return []
        return view.windows
    }

    readonly property int overflowCount: {
        const view = root.windowView
        if (!view || typeof view.overflow !== "number")
            return 0
        return view.overflow
    }

    implicitWidth: Math.max(implicitHeight, cluster.implicitWidth + pad * 2)
    implicitHeight: slot + pad * 2
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + pad
    color: tokens.color.surfaceAlt
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.desktopEpoch += 1
        }
    }

    function listCount(list) {
        if (list === null || list === undefined)
            return 0
        if (typeof list !== "object")
            return 0
        if (typeof list.count === "number")
            return list.count
        if (typeof list.length === "number")
            return list.length
        return 0
    }

    function listAt(list, index) {
        if (list === null || list === undefined)
            return null
        try {
            if (typeof list.length === "number")
                return list[index]
            if (typeof list.get === "function")
                return list.get(index)
        } catch (error) {
            return null
        }
        return null
    }

    function sameId(a, b) {
        if (a === b)
            return true
        if (a === undefined || a === null || b === undefined || b === null)
            return false
        return String(a) === String(b)
    }

    // Окна сфокусированного стола на выбранном выходе.
    // Пустой outputName уже заменён на Niri.focusedOutput.
    function collect(output, workspaces, windows) {
        const none = { windows: [], overflow: 0 }
        if (!output)
            return none

        const wsCount = root.listCount(workspaces)
        let chosenId = null
        let activeId = null
        let haveChosen = false
        let haveActive = false
        for (let i = 0; i < wsCount; i++) {
            const ws = root.listAt(workspaces, i)
            if (!ws || ws.output !== output)
                continue
            if (ws.focused === true) {
                chosenId = ws.id
                haveChosen = true
                break
            }
            if (ws.active === true && !haveActive) {
                activeId = ws.id
                haveActive = true
            }
        }
        if (!haveChosen && haveActive) {
            chosenId = activeId
            haveChosen = true
        }
        if (!haveChosen)
            return none

        const winCount = root.listCount(windows)
        const matched = []
        for (let i = 0; i < winCount; i++) {
            const w = root.listAt(windows, i)
            if (!w)
                continue
            if (w.output && w.output !== output)
                continue
            if (!root.sameId(w.workspaceId, chosenId))
                continue
            matched.push({
                windowId: w.id,
                appId: w.appId ? String(w.appId) : "",
                title: w.title ? String(w.title) : "",
                focused: w.focused === true
            })
        }

        if (matched.length <= root.maxVisible)
            return { windows: matched, overflow: 0 }

        let focusIndex = -1
        for (let i = 0; i < matched.length; i++) {
            if (matched[i].focused) {
                focusIndex = i
                break
            }
        }

        const visible = []
        if (focusIndex >= root.maxVisible) {
            visible.push(matched[focusIndex])
            for (let i = 0; i < matched.length && visible.length < root.maxVisible; i++) {
                if (i !== focusIndex)
                    visible.push(matched[i])
            }
        } else {
            for (let i = 0; i < root.maxVisible; i++)
                visible.push(matched[i])
        }
        return { windows: visible, overflow: matched.length - visible.length }
    }

    function entryFor(appId) {
        if (typeof DesktopEntries === "undefined" || !DesktopEntries)
            return null
        const id = String(appId || "").trim()
        if (id.length === 0)
            return null
        const bare = id.endsWith(".desktop") ? id.slice(0, id.length - 8) : id
        try {
            let entry = DesktopEntries.byId(bare)
            if (!entry && bare !== id)
                entry = DesktopEntries.byId(id)
            if (!entry)
                entry = DesktopEntries.heuristicLookup(bare)
            return entry
        } catch (error) {
            return null
        }
    }

    // Путь локальной темы или пустая строка. Сеть и новый набор иконок не используются.
    function iconFor(appId) {
        const entry = root.entryFor(appId)
        if (!entry || !entry.icon)
            return ""
        const name = String(entry.icon)
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

    function monogram(appId) {
        const raw = String(appId || "").trim()
        if (raw.length === 0)
            return ""
        const pieces = raw.split(".")
        let leaf = pieces[pieces.length - 1]
        if (leaf.length === 0 && pieces.length > 1)
            leaf = pieces[pieces.length - 2]
        for (let i = 0; i < leaf.length; i++) {
            const code = leaf.charCodeAt(i)
            const digit = code >= 48 && code <= 57
            const latin = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
            if (digit || latin)
                return leaf.charAt(i).toUpperCase()
        }
        return ""
    }

    // Только из клика. При создании острова окно не фокусируется.
    function focusAt(windowId) {
        if (windowId === undefined || windowId === null || windowId === "")
            return
        try {
            if (typeof Niri === "undefined" || !Niri || !Niri.focusWindow)
                return
            Niri.focusWindow(windowId)
        } catch (error) {
            return
        }
    }

    component WindowMark: Item {
        id: mark

        required property int index
        required property var modelData

        readonly property var windowId: modelData ? modelData.windowId : null
        readonly property string appId: modelData && modelData.appId ? String(modelData.appId) : ""
        readonly property string title: modelData && modelData.title ? String(modelData.title) : ""
        readonly property bool focused: !!(modelData && modelData.focused)

        readonly property string iconUrl: root.desktopEpoch >= 0 ? root.iconFor(appId) : ""
        readonly property bool showLetter: iconUrl === "" || iconImage.status === Image.Error

        x: index * (root.slot + root.gap)
        y: 0
        width: root.slot
        height: root.slot

        Accessible.role: Accessible.Button
        Accessible.name: title.length > 0 ? title : appId
        Accessible.onPressAction: root.focusAt(windowId)

        Rectangle {
            anchors.fill: parent
            radius: root.tokens.radius.small
            color: mark.focused ? root.tokens.color.surface : "transparent"
            border.width: mark.focused ? 1 : 0
            border.color: root.tokens.color.accent
            antialiasing: true
        }

        IconImage {
            id: iconImage
            anchors.centerIn: parent
            implicitSize: root.tokens.spacing.medium
            width: implicitSize
            height: implicitSize
            visible: mark.iconUrl !== "" && status !== Image.Error
            source: mark.iconUrl
            asynchronous: true
            mipmap: true
        }

        Text {
            id: letter
            visible: mark.showLetter && text.length > 0
            anchors.centerIn: parent
            text: root.monogram(mark.appId)
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
            font.letterSpacing: root.tokens.type.body.letterSpacing
            lineHeight: 1
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }

        Rectangle {
            visible: mark.showLetter && letter.text.length === 0
            anchors.centerIn: parent
            width: root.tokens.spacing.small
            height: width
            radius: width / 2
            color: root.tokens.color.accentSoft
            antialiasing: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusAt(mark.windowId)
        }
    }

    Item {
        id: cluster
        anchors.centerIn: parent

        readonly property int count: {
            const list = root.visibleWindows
            return list && typeof list.length === "number" ? list.length : 0
        }
        readonly property int iconsWidth: count > 0 ? count * root.slot + (count - 1) * root.gap : 0
        readonly property int overflowPad: root.overflowCount > 0
                ? root.gap + overflowLabel.implicitWidth : 0

        implicitWidth: iconsWidth + overflowPad
        implicitHeight: root.slot
        width: implicitWidth
        height: implicitHeight

        Repeater {
            model: root.visibleWindows
            delegate: WindowMark {}
        }

        Text {
            id: overflowLabel
            visible: root.overflowCount > 0
            x: cluster.iconsWidth + (cluster.iconsWidth > 0 ? root.gap : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + root.overflowCount
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            font.weight: root.tokens.type.small.weight
            font.letterSpacing: root.tokens.type.small.letterSpacing
            lineHeight: root.tokens.type.small.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }
}
