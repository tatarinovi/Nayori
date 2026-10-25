pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../../tokens"
import "../../services"

// Содержимое лаунчера без своего окна. Хост ставит элемент в слой,
// который сам создаёт на время открытия, и вызывает open() / focusInput().
Item {
    id: root

    property bool opened: false
    property int selectedIndex: 0

    signal closeRequested()
    signal launched(string id)

    property int panelWidth: 560
    readonly property int panelMaxHeight: 420
    readonly property int pad: tokens.spacing.medium

    readonly property bool searching: catalog.normalizedQuery.length > 0

    readonly property string emptyText: {
        const list = catalog.results
        const count = list && typeof list.length === "number" ? list.length : 0
        if (!catalog.catalogReady || count > 0)
            return ""
        if (root.searching)
            return "Nothing matches"
        if (catalog.applicationCount === 0)
            return "No applications"
        return ""
    }

    implicitWidth: root.panelWidth
    implicitHeight: Math.min(root.panelMaxHeight, column.implicitHeight + root.pad * 2)
    width: implicitWidth
    height: implicitHeight

    Tokens {
        id: tokens
    }

    // Свойство детей тоже называется tokens. Отдельное имя, чтобы не связать его само с собой.
    readonly property var tokenSet: tokens

    Apps {
        id: catalog
    }

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

    // Имеет смысл, когда слой хоста уже показан и может взять клавиатуру.
    function focusInput() {
        field.forceActiveFocus()
    }

    function resultCount() {
        const list = catalog.results
        if (!list || typeof list.length !== "number")
            return 0
        return list.length
    }

    function activeCount() {
        if (root.searching)
            return root.resultCount()
        const list = catalog.favorites
        if (!list || typeof list.length !== "number")
            return 0
        return list.length
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
        if (root.searching) {
            root.launchIndex(root.selectedIndex)
            return
        }
        const list = catalog.favorites
        if (!list || root.selectedIndex < 0 || root.selectedIndex >= list.length)
            return
        const card = list[root.selectedIndex]
        const entryId = card && card.id ? String(card.id) : ""
        root.launchId(entryId)
    }

    function handleKey(event) {
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
        function onFavoritesChanged() {
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

    RectangularShadow {
        anchors.fill: chrome
        radius: chrome.radius
        blur: 16
        spread: 0
        offset: Qt.vector2d(0, 6)
        color: tokens.color.shadow
        z: -1
    }

    Rectangle {
        id: chrome
        anchors.fill: parent
        radius: tokens.radius.medium
        color: tokens.color.background
        border.width: 1
        border.color: tokens.color.border
        antialiasing: true
        clip: column.implicitHeight + root.pad * 2 > root.panelMaxHeight

        Column {
            id: column
            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: tokens.spacing.small

            Item {
                id: heading
                width: column.width
                implicitHeight: kicker.implicitHeight
                height: implicitHeight

                Rectangle {
                    y: (parent.height - height) / 2
                    width: 2
                    height: Math.max(10, Math.round(kicker.implicitHeight * 0.7))
                    radius: 1
                    color: tokens.color.secondary
                    antialiasing: true
                }

                Row {
                    id: kicker
                    x: tokens.spacing.small + 2
                    spacing: tokens.spacing.small

                    Text {
                        text: "NAYORI"
                        color: tokens.color.text
                        font.family: tokens.type.small.family
                        font.pixelSize: tokens.type.small.size
                        font.weight: tokens.type.small.weight
                        font.letterSpacing: tokens.type.small.letterSpacing
                        lineHeight: tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "/"
                        color: tokens.color.secondary
                        font.family: tokens.type.small.family
                        font.pixelSize: tokens.type.small.size
                        font.weight: tokens.type.small.weight
                        font.letterSpacing: tokens.type.small.letterSpacing
                        lineHeight: tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: "APPLICATIONS"
                        color: tokens.color.textMuted
                        font.family: tokens.type.small.family
                        font.pixelSize: tokens.type.small.size
                        font.weight: tokens.type.small.weight
                        font.letterSpacing: tokens.type.small.letterSpacing
                        lineHeight: tokens.type.small.lineHeight
                        lineHeightMode: Text.ProportionalHeight
                        renderType: Text.NativeRendering
                        textFormat: Text.PlainText
                    }
                }
            }

            Rectangle {
                id: searchBox
                width: column.width
                height: 40
                radius: tokens.radius.small
                color: tokens.color.surfaceAlt
                border.width: 1
                border.color: field.activeFocus ? tokens.color.accent : tokens.color.border
                antialiasing: true

                Behavior on border.color {
                    ColorAnimation {
                        duration: tokens.motion.fast
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: tokens.spacing.medium
                    anchors.rightMargin: tokens.spacing.medium
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text.length === 0 && field.preeditText.length === 0
                    text: "Search"
                    color: tokens.color.textMuted
                    font.family: tokens.type.body.family
                    font.pixelSize: tokens.type.body.size
                    font.weight: tokens.type.body.weight
                    font.letterSpacing: tokens.type.body.letterSpacing
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: tokens.spacing.medium
                    anchors.rightMargin: tokens.spacing.medium
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: tokens.color.text
                    selectionColor: tokens.color.accentSoft
                    selectedTextColor: tokens.color.text
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    activeFocusOnTab: true
                    font.family: tokens.type.body.family
                    font.pixelSize: tokens.type.body.size
                    font.weight: tokens.type.body.weight
                    font.letterSpacing: tokens.type.body.letterSpacing

                    Accessible.name: "Search applications"

                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) { root.handleKey(event) }

                    onTextChanged: {
                        root.selectedIndex = 0
                        catalog.query = field.text
                    }
                }
            }

            FavoriteApps {
                id: favorites
                width: column.width
                tokens: root.tokenSet
                entries: root.searching ? [] : catalog.favorites
                selectedIndex: root.searching ? -1 : root.selectedIndex
                onActivated: function(entryId) { root.launchId(entryId) }
                onHovered: function(index) {
                    if (!root.searching)
                        root.selectedIndex = index
                }
            }

            SearchResults {
                id: results
                width: column.width
                tokens: root.tokenSet
                entries: catalog.results
                selectedIndex: root.searching ? root.selectedIndex : -1
                emptyText: root.emptyText
                onActivated: function(index) { root.launchIndex(index) }
                onHighlighted: function(index) {
                    if (root.searching)
                        root.selectedIndex = index
                }
            }

            Row {
                id: hint
                spacing: tokens.spacing.medium

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
