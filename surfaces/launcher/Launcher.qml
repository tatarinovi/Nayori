pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../../tokens"
import "../../services"

// Содержимое лаунчера без своего окна. Хост ставит элемент в слой,
// который сам создаёт на время открытия, и вызывает open() / focusInput().
Item {
    id: root

    property var tokens: fallbackTokens
    property bool opened: false
    property bool embedded: false
    property int selectedIndex: 0

    signal closeRequested()
    signal launched(string id)

    property int panelWidth: 560
    readonly property int panelMaxHeight: 420
    readonly property int padX: root.embedded ? 0 : root.tokens.spacing.medium
    readonly property int padY: root.embedded ? 0 : root.tokens.spacing.medium
    // The embedded row is the island capsule: 48 tall, text inset like the island.
    readonly property int rowHeight: 48
    readonly property int textInset: 22
    readonly property int searchIconSize: 22
    // Подписи клавиш плашки справа. Единственное место, где они заданы.
    readonly property var openShortcut: ["Alt", "Space"]
    // Крупнее текста панели: строка поиска острова читается как главный элемент.
    readonly property int fieldFontSize: root.embedded ? root.tokens.type.body.size + 2 : root.tokens.type.body.size
    readonly property color placeholderInk: Qt.alpha(root.tokens.color.textMuted, 0.7)
    readonly property real fieldX: root.embedded
        ? root.textInset + root.searchIconSize + root.tokens.spacing.medium - 2
        : root.tokens.spacing.medium
    // Справа в строке стоит плашка с сочетанием открытия; поле заканчивается перед ней.
    readonly property real fieldReserve: root.embedded
        ? shortcutHint.width + root.textInset + root.tokens.spacing.small
        : root.tokens.spacing.medium

    readonly property bool searching: catalog.normalizedQuery.length > 0
    readonly property string webTerms: root.webTermsFor(field.text)
    readonly property bool webOffered: root.webTerms.length > 0
    readonly property bool listWanted: {
        const list = catalog.results
        const count = list && typeof list.length === "number" ? list.length : 0
        return root.searching && (count > 0 || root.webOffered || root.emptyText.length > 0)
    }

    readonly property string emptyText: {
        const list = catalog.results
        const count = list && typeof list.length === "number" ? list.length : 0
        if (!catalog.catalogReady || count > 0 || root.webOffered)
            return ""
        if (root.searching)
            return "Ничего не нашлось"
        if (catalog.applicationCount === 0)
            return "Нет приложений"
        return ""
    }

    implicitWidth: root.panelWidth
    implicitHeight: root.embedded
        ? root.rowHeight
        : Math.min(root.panelMaxHeight, column.implicitHeight + root.padY * 2)
    // Во встроенном виде строка идёт за шириной капсулы: рамка и поле растут вместе с ней.
    width: root.embedded && root.parent && root.parent.width > 0 ? root.parent.width : implicitWidth
    height: implicitHeight

    Tokens {
        id: fallbackTokens
    }

    // Свойство детей тоже называется root.tokens. Отдельное имя, чтобы не связать его само с собой.
    readonly property var tokenSet: tokens

    Apps {
        id: catalog
    }
    readonly property var catalogResults: catalog.results

    function open() {
        root.opened = true
        root.selectedIndex = 0
        field.text = ""
        catalog.query = ""
        Qt.callLater(root.focusInput)
    }

    function close() {
        root.opened = false
        field.focus = false
    }

    readonly property bool inputFocused: field.activeFocus
    // The layer surface's backing window. PanelWindow itself has no `active`.
    readonly property var hostWindow: field.Window.window

    // Keyboard focus on a layer surface arrives after the compositor acks it.
    // forceActiveFocus before that ack does not stick.
    function focusInput() {
        if (!root.opened)
            return
        const win = field.Window.window
        if (!win || !win.visible || !win.active)
            return
        if (!field.activeFocus)
            field.forceActiveFocus(Qt.ShortcutFocusReason)
    }

    onHostWindowChanged: root.focusInput()
    Connections {
        target: root.hostWindow
        function onActiveChanged() { root.focusInput() }
        function onVisibleChanged() { root.focusInput() }
    }

    function resultCount() {
        const list = catalog.results
        if (!list || typeof list.length !== "number")
            return 0
        return list.length
    }

    // «web запрос» — явный поиск, как в angelOS. Остальной текст тоже можно найти в интернете.
    // Поисковик в Nayori не задан: URL Google, браузер по умолчанию.
    function webTermsFor(text) {
        const raw = String(text === undefined || text === null ? "" : text).trim().replace(/\s+/g, " ")
        if (raw.length === 0)
            return ""
        const prefixed = /^web\s+(.+)$/i.exec(raw)
        if (prefixed)
            return String(prefixed[1]).trim()
        if (/^web$/i.test(raw))
            return ""
        return raw
    }

    function searchUrl(terms) {
        const text = String(terms === undefined || terms === null ? "" : terms).trim()
        if (text.length === 0)
            return ""
        return "https://www.google.com/search?q=" + encodeURIComponent(text)
    }

    function openWebSearch() {
        const url = root.searchUrl(root.webTerms)
        if (url.length === 0)
            return
        let opened = false
        try {
            opened = Qt.openUrlExternally(url)
        } catch (error) {
            opened = false
        }
        if (!opened) {
            webLaunch.command = ["xdg-open", url]
            webLaunch.startDetached()
        }
        root.close()
        root.closeRequested()
    }

    function activeCount() {
        if (!root.searching)
            return 0
        return root.resultCount() + (root.webOffered ? 1 : 0)
    }

    function clampSelection() {
        const count = root.activeCount()
        if (count <= 0) {
            root.selectedIndex = 0
            return
        }
        if (root.selectedIndex < 0)
            root.selectedIndex = 0
        else if (root.selectedIndex >= count)
            root.selectedIndex = count - 1
    }

    function moveSelection(delta) {
        const count = root.activeCount()
        if (count <= 0)
            return
        let next = root.selectedIndex + delta
        if (next < 0)
            next = 0
        if (next >= count)
            next = count - 1
        root.selectedIndex = next
    }

    function launchId(entryId) {
        const launchedId = catalog.launch(entryId)
        if (!launchedId)
            return
        root.launched(launchedId)
        root.close()
        root.closeRequested()
    }

    function launchIndex(index) {
        const list = catalog.results
        if (!list || index < 0 || index >= list.length)
            return
        const card = list[index]
        const entryId = card && card.id ? String(card.id) : ""
        root.launchId(entryId)
    }

    function launchSelected() {
        root.clampSelection()
        if (!root.searching)
            return
        if (root.webOffered && root.selectedIndex === root.resultCount()) {
            root.openWebSearch()
            return
        }
        root.launchIndex(root.selectedIndex)
    }

    // Ctrl+K (дополнительно, не подсказывается): вернуть ввод в поле и выделить запрос целиком.
    // Скан-код 45 — клавиша K на любой раскладке (на русской event.key не Qt.Key_K).
    function selectQuery() {
        if (!root.opened)
            return
        field.forceActiveFocus(Qt.ShortcutFocusReason)
        field.selectAll()
    }

    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
            && (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) === 0
        if (ctrl && (event.key === Qt.Key_K || event.nativeScanCode === 45)) {
            root.selectQuery()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up) {
            root.moveSelection(-1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down) {
            root.moveSelection(1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launchSelected()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
            root.closeRequested()
        }
    }

    Connections {
        target: catalog
        function onResultsChanged() {
            root.clampSelection()
        }
    }

    component KeyHint: Row {
        id: hintPair

        required property var tokenSet
        required property string keyText
        required property string caption

        spacing: hintPair.tokenSet.spacing.small

        Text {
            text: hintPair.keyText
            color: hintPair.tokenSet.color.secondary
            font.family: hintPair.tokenSet.type.small.family
            font.pixelSize: hintPair.tokenSet.type.small.size
            font.weight: hintPair.tokenSet.type.small.weight
            font.letterSpacing: hintPair.tokenSet.type.small.letterSpacing
            lineHeight: hintPair.tokenSet.type.small.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }

        Text {
            text: hintPair.caption
            color: hintPair.tokenSet.color.textMuted
            font.family: hintPair.tokenSet.type.small.family
            font.pixelSize: hintPair.tokenSet.type.small.size
            font.weight: hintPair.tokenSet.type.small.weight
            font.letterSpacing: hintPair.tokenSet.type.small.letterSpacing
            lineHeight: hintPair.tokenSet.type.small.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }

    component KeyCap: Rectangle {
        id: cap

        required property var tokenSet
        required property string label

        implicitWidth: Math.max(28, capText.implicitWidth + cap.tokenSet.spacing.small * 2)
        implicitHeight: 24
        width: implicitWidth
        height: implicitHeight
        radius: cap.tokenSet.radius.small
        color: cap.tokenSet.color.surfaceAlt
        border.width: 1
        border.color: cap.tokenSet.color.border
        antialiasing: true

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            color: Qt.alpha(cap.tokenSet.color.textMuted, 0.85)
            font.family: cap.tokenSet.type.small.family
            font.pixelSize: cap.tokenSet.type.small.size - 1
            font.weight: cap.tokenSet.type.small.weight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }

    Process { id: webLaunch }

    RectangularShadow {
        anchors.fill: chrome
        visible: !root.embedded
        radius: chrome.radius
        blur: 16
        spread: 0
        offset: Qt.vector2d(0, 6)
        color: root.tokens.color.shadow
        z: -1
    }

    Rectangle {
        id: chrome
        anchors.fill: parent
        radius: root.embedded ? 0 : root.tokens.radius.medium
        color: root.embedded ? "transparent" : root.tokens.material.dense
        border.width: root.embedded ? 0 : 1
        border.color: root.tokens.color.border
        antialiasing: true
        clip: column.implicitHeight + root.padY * 2 > root.panelMaxHeight

        // Строка поиска острова: тёмная подложка и лавандовая рамка поверх капсулы.
        // Проявляются вместе с раскрытием; рамка капсулы под ними остаётся нетронутой.
        Rectangle {
            id: barFill
            anchors.fill: parent
            visible: root.embedded && !root.tokens.frosted
            radius: Math.min(height / 2, 24)
            color: root.tokens.color.background
            opacity: root.opened ? 1 : 0
            antialiasing: true

            Behavior on opacity {
                NumberAnimation {
                    duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: barRing
            anchors.fill: parent
            visible: root.embedded
            radius: Math.min(height / 2, 24)
            color: "transparent"
            border.width: 1
            border.color: field.activeFocus ? root.tokens.color.accentBorder : root.tokens.color.accentSoft
            opacity: root.opened ? 1 : 0
            antialiasing: true

            Behavior on opacity {
                NumberAnimation {
                    duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            id: column
            x: root.padX
            y: root.padY
            width: parent.width - root.padX * 2
            spacing: root.embedded ? 0 : root.tokens.spacing.small

            Item {
                id: heading
                visible: !root.embedded
                width: column.width
                implicitHeight: kicker.implicitHeight
                height: implicitHeight

                Rectangle {
                    y: (parent.height - height) / 2
                    width: 2
                    height: Math.max(10, Math.round(kicker.implicitHeight * 0.7))
                    radius: 1
                    color: root.tokens.color.secondary
                    antialiasing: true
                }

                Row {
                    id: kicker
                    x: root.tokens.spacing.small + 2
                    spacing: root.tokens.spacing.small

                    Text {
                        text: "NAYORI"
                        color: root.tokens.color.text
                        font.family: root.tokens.type.small.family
                        font.pixelSize: root.tokens.type.small.size
                        font.weight: root.tokens.type.small.weight
                        font.letterSpacing: root.tokens.type.small.letterSpacing
                        lineHeight: root.tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "/"
                        color: root.tokens.color.secondary
                        font.family: root.tokens.type.small.family
                        font.pixelSize: root.tokens.type.small.size
                        font.weight: root.tokens.type.small.weight
                        font.letterSpacing: root.tokens.type.small.letterSpacing
                        lineHeight: root.tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "APPLICATIONS"
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

            Item {
                id: searchBox
                width: column.width
                height: root.embedded ? root.rowHeight : 40

                Rectangle {
                    anchors.fill: parent
                    visible: !root.embedded
                    radius: root.tokens.radius.small
                    color: root.tokens.color.surfaceAlt
                    border.width: 1
                    border.color: field.activeFocus ? root.tokens.color.accent : root.tokens.color.border
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation {
                            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                LauncherGlyph {
                    id: searchIcon
                    visible: root.embedded
                    x: root.textInset
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.searchIconSize
                    height: root.searchIconSize
                    kind: "search"
                    ink: root.tokens.color.text
                }

                // Плашка показывает сочетание открытия (openShortcut). Само сочетание задаёт
                // niri (`Alt+Space ... qs ipc call launcher toggle`), поэтому подписи только здесь.
                Row {
                    id: shortcutHint
                    visible: root.embedded
                    anchors.right: parent.right
                    anchors.rightMargin: root.textInset - root.tokens.spacing.small / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.tokens.spacing.small / 2

                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Открывается: " + root.openShortcut.join("+")

                    Repeater {
                        model: root.openShortcut
                        delegate: KeyCap {
                            required property string modelData
                            tokenSet: root.tokenSet
                            label: modelData
                        }
                    }
                }

                Item {
                    id: fieldArea
                    x: root.fieldX
                    width: Math.max(0, parent.width - root.fieldX - root.fieldReserve)
                    height: parent.height
                    clip: true

                    Text {
                        // Подсказка стоит правее каретки, а не под ней: первая буква не режется.
                        x: root.embedded ? root.tokens.spacing.small + 2 : 0
                        width: Math.max(0, parent.width - x)
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text.length === 0 && field.preeditText.length === 0
                        text: root.embedded ? "Найти приложения, файлы, команды…" : "Поиск"
                        color: root.placeholderInk
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: root.tokens.type.body.family
                        font.pixelSize: root.fieldFontSize
                        font.weight: root.tokens.type.body.weight
                        font.letterSpacing: root.tokens.type.body.letterSpacing
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    TextInput {
                        id: field
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.tokens.color.text
                        selectionColor: root.tokens.color.accentSoft
                        selectedTextColor: root.tokens.color.accentSoftText
                        renderType: Text.NativeRendering
                        selectByMouse: true
                        activeFocusOnTab: true
                        font.family: root.tokens.type.body.family
                        font.pixelSize: root.fieldFontSize
                        font.weight: root.tokens.type.body.weight
                        font.letterSpacing: root.tokens.type.body.letterSpacing

                        cursorDelegate: Rectangle {
                            width: 2
                            radius: 1
                            color: root.tokens.color.accent
                            antialiasing: true
                        }

                        Accessible.name: "Поиск"

                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: function(event) { root.handleKey(event) }

                        onTextChanged: {
                            root.selectedIndex = 0
                            catalog.query = field.text
                        }
                    }
                }
            }

            Item {
                id: tail
                width: column.width
                visible: !root.embedded && (results.visible || webRow.visible)
                implicitHeight: visible
                    ? tailColumn.y + tailColumn.implicitHeight + (root.embedded ? root.tokens.spacing.medium : 0)
                    : 0
                height: implicitHeight

                Column {
                    id: tailColumn
                    x: root.embedded ? root.textInset : 0
                    y: root.embedded ? root.tokens.spacing.small : 0
                    width: parent.width - x * 2
                    spacing: root.tokens.spacing.small

            SearchResults {
                id: results
                width: tailColumn.width
                tokens: root.tokenSet
                entries: catalog.results
                selectedIndex: root.searching && root.selectedIndex < root.resultCount() ? root.selectedIndex : -1
                emptyText: root.emptyText
                trailingRow: root.webOffered
                trailingSelected: root.webOffered && root.searching && root.selectedIndex === root.resultCount()
                onActivated: function(index) { root.launchIndex(index) }
                onHighlighted: function(index) {
                    if (root.searching)
                        root.selectedIndex = index
                }
            }

            Item {
                id: webRow
                visible: root.webOffered
                width: tailColumn.width
                implicitHeight: 40
                height: implicitHeight

                readonly property bool selected: root.searching && root.selectedIndex === root.resultCount()

                Accessible.role: Accessible.Button
                Accessible.name: "Найти в\u00A0интернете: " + root.webTerms
                Accessible.onPressAction: root.openWebSearch()

                Rectangle {
                    anchors.fill: parent
                    radius: root.tokens.radius.small
                    color: webRow.selected ? root.tokens.color.surface : "transparent"
                    antialiasing: true
                }

                Rectangle {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 16
                    radius: 1
                    color: root.tokens.color.secondary
                    opacity: webRow.selected ? 1 : 0
                    antialiasing: true
                }

                Text {
                    id: webLabel
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Найти в\u00A0интернете"
                    color: root.tokens.color.text
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    font.weight: root.tokens.type.body.weight
                    font.letterSpacing: root.tokens.type.body.letterSpacing
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                Text {
                    anchors.left: webLabel.right
                    anchors.leftMargin: root.tokens.spacing.small
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.webTerms
                    color: root.tokens.color.textMuted
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: root.tokens.type.small.family
                    font.pixelSize: root.tokens.type.small.size
                    font.weight: root.tokens.type.small.weight
                    font.letterSpacing: root.tokens.type.small.letterSpacing
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = root.resultCount()
                    onPressed: root.selectedIndex = root.resultCount()
                    onClicked: root.openWebSearch()
                }
            }
                }
            }

            Row {
                id: hint
                visible: !root.embedded
                spacing: root.tokens.spacing.medium

                Accessible.role: Accessible.StaticText
                Accessible.name: "Up and down select, enter opens, escape closes"

                KeyHint {
                    tokenSet: root.tokenSet
                    keyText: "↑↓"
                    caption: "select"
                }
                KeyHint {
                    tokenSet: root.tokenSet
                    keyText: "enter"
                    caption: "open"
                }
                KeyHint {
                    tokenSet: root.tokenSet
                    keyText: "esc"
                    caption: "close"
                }
            }
        }
    }
}
