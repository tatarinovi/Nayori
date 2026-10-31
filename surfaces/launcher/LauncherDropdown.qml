pragma ComponentBehavior: Bound

import QtQuick

// Список под строкой поиска. Живёт в своём окне и не меняет высоту острова.
Item {
    id: root

    required property var tokens
    property var host: null

    readonly property bool live: host !== null
    readonly property int bodyMax: 420
    implicitWidth: column.implicitWidth
    implicitHeight: Math.min(Math.max(column.implicitHeight, 1), root.bodyMax)
    height: implicitHeight

    Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentHeight > height + 1

        Column {
            id: column
            width: scroller.width
            spacing: 0

            SearchResults {
                width: column.width
                tokens: root.tokens
                entries: root.live ? root.host.rows : []
                selectedIndex: root.live && root.host.searching ? root.host.selectedIndex : -1
                emptyText: root.live ? root.host.emptyText : ""
                onActivated: function(index) {
                    if (root.live)
                        root.host.launchIndex(index)
                }
                onHighlighted: function(index) {
                    if (root.live && root.host.searching)
                        root.host.highlightIndex(index)
                }
                onSelectionGeometry: function(itemY, itemHeight) {
                    if (itemHeight <= 0 || scroller.height <= 0)
                        return
                    if (itemY < scroller.contentY)
                        scroller.contentY = itemY
                    else if (itemY + itemHeight > scroller.contentY + scroller.height)
                        scroller.contentY = Math.max(0, itemY + itemHeight - scroller.height)
                }
            }

            Text {
                width: column.width
                visible: root.live && root.host.statusText.length > 0
                text: root.live ? root.host.statusText : ""
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
}
