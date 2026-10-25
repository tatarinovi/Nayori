pragma ComponentBehavior: Bound

import QtQuick

// Список уже отобранных ярлыков. Своей оценки строки здесь нет.
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
    Accessible.name: "Application results"

    function titleOf(data) {
        if (!data || data.name === undefined || data.name === null)
            return ""
        return String(data.name)
    }

    function asideOf(data) {
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
            model: root.rows
            delegate: LauncherRow {
                id: delegate

                required property int index
                required property var modelData

                width: listColumn.width
                tokenSet: root.tokens
                title: root.titleOf(delegate.modelData)
                subtitle: root.asideOf(delegate.modelData)
                iconSource: root.iconOf(delegate.modelData)
                selected: delegate.index === root.selectedIndex
                separator: root.separatorAfter(delegate.index)
                onPicked: root.activated(delegate.index)
                onHovered: root.highlighted(delegate.index)
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
