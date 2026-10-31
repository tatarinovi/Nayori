pragma ComponentBehavior: Bound

import QtQuick

// Список уже собранных строк: приложение, файл, папка, команда, интернет.
Item {
    id: root

    required property var tokens
    property var entries: []
    property int selectedIndex: 0
    property string emptyText: ""
    // Под списком есть ещё одна строка (поиск в интернете), и выбрана ли она.
    // Нужно только для разделителей: рядом с выбранной строкой их нет.
    property bool trailingRow: false
    property bool trailingSelected: false

    signal activated(int index)
    signal highlighted(int index)

    readonly property var rows: {
        const list = root.entries
        if (!list || typeof list.length !== "number")
            return []
        return list
    }

    visible: root.emptyText.length > 0 || root.rows.length > 0
    implicitHeight: visible ? listColumn.implicitHeight : 0
    height: implicitHeight

    Accessible.role: Accessible.List
    Accessible.name: "Результаты поиска"

    signal selectionGeometry(real itemY, real itemHeight)

    function textOf(data, key) {
        if (!data || data[key] === undefined || data[key] === null)
            return ""
        return String(data[key])
    }

    function titleOf(data) {
        const title = root.textOf(data, "title")
        if (title.length > 0)
            return title
        return root.textOf(data, "name")
    }

    function asideOf(data) {
        const subtitle = root.textOf(data, "subtitle")
        if (subtitle.length > 0)
            return subtitle
        if (!data || data.genericName === undefined || data.genericName === null)
            return ""
        const generic = String(data.genericName).trim()
        if (generic.length === 0)
            return ""
        if (generic.toLocaleLowerCase() === root.titleOf(data).toLocaleLowerCase())
            return ""
        return generic
    }

    function iconOf(data) {
        if (!data || !data.iconSource)
            return ""
        return String(data.iconSource)
    }

    function revealSelection() {
        if (root.selectedIndex < 0)
            return
        const item = resultRepeater.itemAt(root.selectedIndex)
        if (!item)
            return
        root.selectionGeometry(item.y, item.height)
    }

    onSelectedIndexChanged: Qt.callLater(root.revealSelection)
    onRowsChanged: Qt.callLater(root.revealSelection)

    function separatorAfter(index) {
        const last = index === root.rows.length - 1
        if (last && !root.trailingRow)
            return false
        if (root.selectedIndex === index || root.selectedIndex === index + 1)
            return false
        return !(last && root.trailingSelected)
    }

    Column {
        id: listColumn
        width: root.width
        spacing: 0

        Repeater {
            id: resultRepeater
            model: root.rows
            delegate: Item {
                id: delegate

                required property int index
                required property var modelData

                readonly property string section: {
                    const value = delegate.modelData ? delegate.modelData.section : ""
                    return value === undefined || value === null ? "" : String(value)
                }

                width: listColumn.width
                implicitHeight: (sectionHeading.visible ? sectionHeading.implicitHeight : 0) + resultRow.height
                height: implicitHeight

                Text {
                    id: sectionHeading
                    width: parent.width
                    visible: delegate.section.length > 0
                    text: delegate.section
                    color: root.tokens.color.textMuted
                    font.family: root.tokens.type.small.family
                    font.pixelSize: root.tokens.type.small.size
                    font.weight: root.tokens.type.small.weight
                    font.letterSpacing: root.tokens.type.small.letterSpacing
                    lineHeight: root.tokens.type.small.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    leftPadding: root.tokens.spacing.medium
                    topPadding: root.tokens.spacing.small
                    bottomPadding: 2
                }

                LauncherRow {
                    id: resultRow
                    y: sectionHeading.visible ? sectionHeading.implicitHeight : 0
                    width: delegate.width
                    tokenSet: root.tokens
                    title: root.titleOf(delegate.modelData)
                    subtitle: root.asideOf(delegate.modelData)
                    iconSource: root.iconOf(delegate.modelData)
                    glyph: root.textOf(delegate.modelData, "glyph")
                    typeLabel: root.textOf(delegate.modelData, "typeLabel")
                    distinct: !!(delegate.modelData && delegate.modelData.distinct)
                    selected: delegate.index === root.selectedIndex
                    separator: root.separatorAfter(delegate.index)
                    onPicked: root.activated(delegate.index)
                    onHovered: root.highlighted(delegate.index)
                }
            }
        }

        Text {
            width: listColumn.width
            height: implicitHeight
            visible: root.emptyText.length > 0
            text: root.emptyText
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
            font.letterSpacing: root.tokens.type.body.letterSpacing
            lineHeight: root.tokens.type.body.lineHeight
            lineHeightMode: Text.ProportionalHeight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            topPadding: root.tokens.spacing.small
            bottomPadding: root.tokens.spacing.small
        }
    }
}
