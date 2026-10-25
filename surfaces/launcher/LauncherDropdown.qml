pragma ComponentBehavior: Bound

import QtQuick

// Список под строкой поиска. Живёт в своём окне и не меняет высоту острова.
Item {
    id: root

    required property var tokens
    property var host: null

    readonly property bool live: host !== null
    readonly property bool webSelected: root.live && root.host.searching
        && root.host.selectedIndex === root.host.resultCount()
    implicitWidth: column.width
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 0

        SearchResults {
            width: column.width
            tokens: root.tokens
            entries: root.live ? root.host.catalogResults : []
            selectedIndex: root.live && root.host.searching && root.host.selectedIndex < root.host.resultCount()
                ? root.host.selectedIndex : -1
            emptyText: root.live ? root.host.emptyText : ""
            trailingRow: root.live && root.host.webOffered
            trailingSelected: root.webSelected
            onActivated: function(index) {
                if (root.live)
                    root.host.launchIndex(index)
            }
            onHighlighted: function(index) {
                if (root.live && root.host.searching)
                    root.host.selectedIndex = index
            }
        }

        LauncherRow {
            id: webRow
            visible: root.live && root.host.webOffered
            width: column.width
            tokenSet: root.tokens
            title: "Поиск в\u00A0интернете"
            subtitle: "Искать в\u00A0Google"
            glyph: "search"
            selected: root.webSelected
            separator: false
            Accessible.name: "Поиск в\u00A0интернете"
            onPicked: if (root.live) root.host.openWebSearch()
            onHovered: if (root.live) root.host.selectedIndex = root.host.resultCount()
        }
    }
}
