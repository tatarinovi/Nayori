pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../../tokens"
import "../../services"
import "../../services/launcher"
import "../../services/launcher/SearchModel.js" as SearchModel

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

    readonly property string queryText: field.text
    readonly property bool commandMode: SearchModel.isCommandQuery(root.queryText)
    readonly property bool searching: SearchModel.normalize(root.queryText).length > 0
    readonly property string webTerms: SearchModel.webTerms(root.queryText)
    readonly property string webUrl: SearchModel.searchUrl(root.webTerms)
    readonly property bool webOffered: root.webTerms.length > 0
    readonly property var rows: SearchModel.buildRows({
        query: root.queryText,
        apps: catalog.results,
        files: fileSearch.files,
        commandOk: fileSearch.commandOk,
        commandPending: fileSearch.commandPending,
        commandArgv: fileSearch.commandArgv,
        commandCode: fileSearch.commandCode,
        commandStatus: fileSearch.status,
        webTerms: root.webTerms,
        webUrl: root.webUrl
    })
    readonly property string statusText: SearchModel.statusLine({
        commandMode: root.commandMode,
        commandBody: SearchModel.commandBody(root.queryText),
        searching: root.searching,
        status: fileSearch.status,
        truncated: fileSearch.truncated,
        fileQueryLength: SearchModel.fileNeedle(root.queryText).length
    })
    readonly property bool listWanted: root.searching && (
        root.rows.length > 0 || root.statusText.length > 0 || root.emptyText.length > 0
    )
    readonly property string emptyText: {
        if (root.searching && root.rows.length === 0 && root.statusText.length === 0)
            return SearchModel.copy("empty")
        if (!root.searching && catalog.catalogReady && catalog.applicationCount === 0)
            return "Нет приложений"
        return ""
    }
    property bool selectionPinned: false
    property string selectedKey: ""
    property bool commandArm: false

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

    FileSearch {
        id: fileSearch
        query: root.opened ? field.text : ""
        onCommandReady: {
            if (root.commandArm && root.opened)
                root.launchCommand()
        }
    }

    function open() {
        field.text = ""
        catalog.query = ""
        root.commandArm = false
        root.resetSelection()
        root.opened = true
        Qt.callLater(root.focusInput)
    }

    function close() {
        root.commandArm = false
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
        const list = root.rows
        if (!list || typeof list.length !== "number")
            return 0
        return list.length
    }

    function resetSelection() {
        root.selectionPinned = false
        root.selectedKey = ""
        root.selectedIndex = 0
    }

    function reconcile() {
        const next = SearchModel.reconcile(root.rows, root.selectedIndex, root.selectedKey, root.selectionPinned)
        root.selectedIndex = next.index
        root.selectedKey = next.key
        root.selectionPinned = next.pinned
    }

    function moveSelection(delta) {
        if (!root.rows || root.rows.length === 0)
            return
        const next = SearchModel.move(root.rows, root.selectedIndex, delta)
        root.selectedIndex = next.index
        root.selectedKey = next.key
        root.selectionPinned = next.pinned
        root.commandArm = false
    }

    function highlightIndex(index) {
        const next = SearchModel.pinAt(root.rows, index)
        if (!next.pinned && root.rows.length === 0)
            return
        root.selectedIndex = next.index
        root.selectedKey = next.key
        root.selectionPinned = next.pinned
    }

    function openWebSearch() {
        const plan = SearchModel.activationPlan({kind: "web", url: root.webUrl})
        if (!plan || plan.action !== "url" || !plan.url)
            return
        let opened = false
        try {
            opened = Qt.openUrlExternally(plan.url)
        } catch (error) {
            opened = false
        }
        if (!opened && plan.fallback && plan.fallback.length === 2) {
            webLaunch.command = plan.fallback
            webLaunch.startDetached()
        }
        root.commandArm = false
        root.close()
        root.closeRequested()
    }

    function launchId(entryId) {
        const launchedId = catalog.launch(entryId)
        if (!launchedId)
            return
        root.launched(launchedId)
        root.commandArm = false
        root.close()
        root.closeRequested()
    }

    function runArgv(argv) {
        const plan = SearchModel.activationPlan({
            kind: "command",
            ok: true,
            pending: false,
            argv: argv
        })
        if (!plan || plan.action !== "argv" || !plan.argv || plan.argv.length === 0)
            return
        commandLaunch.command = plan.argv
        commandLaunch.startDetached()
        root.commandArm = false
        root.close()
        root.closeRequested()
    }

    function openPath(path) {
        const plan = SearchModel.activationPlan({kind: "file", path: path})
        if (!plan || plan.action !== "argv")
            return
        let opened = false
        try {
            const url = SearchModel.fileUrl(path)
            opened = url.length > 0 && Qt.openUrlExternally(url)
        } catch (error) {
            opened = false
        }
        if (!opened) {
            fileLaunch.command = plan.argv
            fileLaunch.startDetached()
        }
        root.commandArm = false
        root.close()
        root.closeRequested()
    }

    // Команда запускается только со строки «команда» и только готовым списком аргументов.
    function launchCommand() {
        if (!root.commandMode) {
            root.commandArm = false
            return
        }
        const list = root.rows
        const row = list && root.selectedIndex >= 0 && root.selectedIndex < list.length
            ? list[root.selectedIndex] : null
        if (row && row.kind !== "command") {
            root.commandArm = false
            return
        }
        if (fileSearch.commandPending || fileSearch.status === "loading") {
            root.commandArm = true
            return
        }
        if (!fileSearch.commandOk) {
            root.commandArm = false
            return
        }
        root.runArgv(fileSearch.commandArgv)
    }

    function launchIndex(index) {
        root.highlightIndex(index)
        root.launchSelected()
    }

    function launchSelected() {
        root.reconcile()
        if (!root.searching)
            return
        const list = root.rows
        if (!list || root.selectedIndex < 0 || root.selectedIndex >= list.length)
            return
        const row = list[root.selectedIndex]
        if (!row)
            return
        if (row.kind === "web") {
            root.commandArm = false
            root.openWebSearch()
            return
        }
        if (row.kind === "command") {
            root.launchCommand()
            return
        }
        if (row.kind === "file" || row.kind === "folder") {
            root.commandArm = false
            root.openPath(row.path)
            return
        }
        if (row.kind === "application") {
            root.commandArm = false
            root.launchId(row.id)
        }
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
            root.reconcile()
        }
    }

    onRowsChanged: Qt.callLater(root.reconcile)

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
    Process { id: fileLaunch }
    Process { id: commandLaunch }

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
                            root.commandArm = false
                            root.resetSelection()
                            catalog.query = SearchModel.isCommandQuery(field.text) ? "" : field.text
                        }
                    }
                }
            }

            Item {
                id: tail
                width: column.width
                visible: !root.embedded && (results.visible || scopeNote.visible)
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
                        entries: root.rows
                        selectedIndex: root.searching ? root.selectedIndex : -1
                        emptyText: root.emptyText
                        onActivated: function(index) { root.launchIndex(index) }
                        onHighlighted: function(index) {
                            if (root.searching)
                                root.highlightIndex(index)
                        }
                    }

                    Text {
                        id: scopeNote
                        width: tailColumn.width
                        visible: root.statusText.length > 0
                        text: root.statusText
                        color: root.tokens.color.textMuted
                        wrapMode: Text.WordWrap
                        font.family: root.tokens.type.small.family
                        font.pixelSize: root.tokens.type.small.size
                        font.weight: root.tokens.type.small.weight
                        font.letterSpacing: root.tokens.type.small.letterSpacing
                        lineHeight: root.tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                        leftPadding: root.tokens.spacing.medium
                        rightPadding: root.tokens.spacing.medium
                        topPadding: root.tokens.spacing.small
                        bottomPadding: root.tokens.spacing.small
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
