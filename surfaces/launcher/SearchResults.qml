pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

// Список уже отобранных ярлыков. Своей оценки строки здесь нет.
Item {
    id: root

    required property var tokens
    property var entries: []
    property int selectedIndex: 0
    property string emptyText: ""

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

    component ResultRow: Item {
        id: row

        required property int index
        required property var modelData
        required property var tokenSet
        required property int currentIndex
        required property int rowWidth
        signal picked(int index)
        signal hovered(int index)

        readonly property bool selected: row.index === row.currentIndex
        readonly property string label: {
            const data = row.modelData
            if (!data || data.name === undefined || data.name === null)
                return ""
            return String(data.name)
        }
        readonly property string iconSource: {
            const data = row.modelData
            if (!data || !data.iconSource)
                return ""
            return String(data.iconSource)
        }
        readonly property string aside: {
            const data = row.modelData
            if (!data || data.genericName === undefined || data.genericName === null)
                return ""
            const generic = String(data.genericName).trim()
            if (generic.length === 0)
                return ""
            if (generic.toLocaleLowerCase() === row.label.toLocaleLowerCase())
                return ""
            return generic
        }
        readonly property bool showLetter: row.iconSource === "" || iconImage.status === Image.Error

        width: row.rowWidth
        height: 40

        Accessible.role: Accessible.Button
        Accessible.name: row.label
        Accessible.onPressAction: row.picked(row.index)

        function monogram(name) {
            const text = String(name === undefined || name === null ? "" : name).trim()
            if (text.length === 0)
                return ""
            return text.charAt(0).toUpperCase()
        }

        Rectangle {
            anchors.fill: parent
            radius: row.tokenSet.radius.small
            color: row.selected ? row.tokenSet.color.surfaceAlt : "transparent"
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: row.tokenSet.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 16
            radius: 1
            color: row.tokenSet.color.secondary
            opacity: row.selected ? 1 : 0
            antialiasing: true

            Behavior on opacity {
                NumberAnimation {
                    duration: row.tokenSet.motion.fast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: glyph
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            IconImage {
                id: iconImage
                anchors.fill: parent
                implicitSize: 18
                visible: row.iconSource !== "" && status !== Image.Error
                source: row.iconSource
                asynchronous: true
                mipmap: true
            }

            Text {
                id: letter
                anchors.centerIn: parent
                visible: row.showLetter && text.length > 0
                text: row.monogram(row.label)
                color: row.tokenSet.color.text
                font.family: row.tokenSet.type.small.family
                font.pixelSize: row.tokenSet.type.small.size
                font.weight: row.tokenSet.type.small.weight
                font.letterSpacing: row.tokenSet.type.small.letterSpacing
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            Rectangle {
                anchors.centerIn: parent
                visible: row.showLetter && letter.text.length === 0
                width: 6
                height: 6
                radius: 3
                color: row.tokenSet.color.accentSoft
                antialiasing: true
            }
        }

        Item {
            id: words
            anchors.left: glyph.right
            anchors.leftMargin: row.tokenSet.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: nameLine.implicitHeight

            Text {
                id: asideText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 168)
                visible: row.aside.length > 0
                text: row.aside
                color: row.tokenSet.color.textMuted
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: row.tokenSet.type.small.family
                font.pixelSize: row.tokenSet.type.small.size
                font.weight: row.tokenSet.type.small.weight
                font.letterSpacing: row.tokenSet.type.small.letterSpacing
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            Text {
                id: nameLine
                anchors.left: parent.left
                anchors.right: asideText.visible ? asideText.left : parent.right
                anchors.rightMargin: asideText.visible ? row.tokenSet.spacing.small : 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: row.tokenSet.color.text
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: row.tokenSet.type.body.family
                font.pixelSize: row.tokenSet.type.body.size
                font.weight: row.tokenSet.type.body.weight
                font.letterSpacing: row.tokenSet.type.body.letterSpacing
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onEntered: row.hovered(row.index)
            onPressed: row.hovered(row.index)
            onClicked: row.picked(row.index)
        }
    }

    Column {
        id: listColumn
        width: root.width
        spacing: Math.round(root.tokens.spacing.small / 2)

        Repeater {
            model: root.rows
            delegate: ResultRow {
                tokenSet: root.tokens
                currentIndex: root.selectedIndex
                rowWidth: root.width
                onPicked: function(index) { root.activated(index) }
                onHovered: function(index) { root.highlighted(index) }
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
        }
    }
}
