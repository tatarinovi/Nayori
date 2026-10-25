pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

// Короткий ряд установленных избранных. Пустой список не занимает места.
Item {
    id: root

    required property var tokens
    property var entries: []
    property int selectedIndex: -1

    signal activated(string entryId)
    signal hovered(int index)

    readonly property int count: {
        const list = root.entries
        if (!list || typeof list.length !== "number")
            return 0
        return list.length
    }

    readonly property int cellWidth: {
        const count = root.count
        if (count <= 0)
            return 0
        const gap = root.tokens.spacing.small
        const available = root.width > 0 ? root.width : 528
        const room = Math.floor((available - gap * (count - 1)) / count)
        if (room <= 0)
            return 72
        if (room < 72)
            return room
        return Math.min(112, room)
    }

    visible: root.count > 0
    implicitWidth: favoriteRow.implicitWidth
    implicitHeight: root.count > 0 ? favoriteRow.implicitHeight : 0
    height: implicitHeight

    Accessible.role: Accessible.List
    Accessible.name: "Favorite applications"

    component FavoriteCard: Rectangle {
        id: card

        required property int index
        required property var modelData
        required property var tokenSet
        required property int cellWidth
        required property int currentIndex
        signal picked(string entryId)
        signal hovered(int index)

        readonly property bool selected: card.index === card.currentIndex

        readonly property string label: {
            const data = card.modelData
            if (!data || data.name === undefined || data.name === null)
                return ""
            return String(data.name)
        }
        readonly property string iconSource: {
            const data = card.modelData
            if (!data || !data.iconSource)
                return ""
            return String(data.iconSource)
        }
        readonly property bool showLetter: card.iconSource === "" || iconImage.status === Image.Error

        width: card.cellWidth
        height: 40
        radius: card.tokenSet.radius.small
        color: (card.selected || hover.containsMouse) ? card.tokenSet.color.surfaceAlt : "transparent"
        border.width: 1
        border.color: card.selected
                ? card.tokenSet.color.secondary
                : (hover.containsMouse ? card.tokenSet.color.accent : card.tokenSet.color.border)
        antialiasing: true

        Accessible.role: Accessible.Button
        Accessible.name: card.label
        Accessible.onPressAction: card.activate()

        Behavior on color {
            ColorAnimation {
                duration: card.tokenSet.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: card.tokenSet.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        function monogram(name) {
            const text = String(name === undefined || name === null ? "" : name).trim()
            if (text.length === 0)
                return ""
            return text.charAt(0).toUpperCase()
        }

        function activate() {
            const data = card.modelData
            const entryId = data && data.id ? String(data.id) : ""
            if (entryId.length === 0)
                return
            card.picked(entryId)
        }

        Item {
            id: glyph
            x: card.tokenSet.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            IconImage {
                id: iconImage
                anchors.fill: parent
                implicitSize: 18
                visible: card.iconSource !== "" && status !== Image.Error
                source: card.iconSource
                asynchronous: true
                mipmap: true
            }

            Text {
                id: letter
                anchors.centerIn: parent
                visible: card.showLetter && text.length > 0
                text: card.monogram(card.label)
                color: card.tokenSet.color.text
                font.family: card.tokenSet.type.small.family
                font.pixelSize: card.tokenSet.type.small.size
                font.weight: card.tokenSet.type.small.weight
                font.letterSpacing: card.tokenSet.type.small.letterSpacing
                renderType: Text.NativeRendering
                textFormat: Text.PlainText
            }

            Rectangle {
                anchors.centerIn: parent
                visible: card.showLetter && letter.text.length === 0
                width: 6
                height: 6
                radius: 3
                color: card.tokenSet.color.accentSoft
                antialiasing: true
            }
        }

        Text {
            anchors.left: glyph.right
            anchors.leftMargin: card.tokenSet.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: card.tokenSet.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            text: card.label
            color: card.tokenSet.color.text
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: card.tokenSet.type.small.family
            font.pixelSize: card.tokenSet.type.small.size
            font.weight: card.tokenSet.type.small.weight
            font.letterSpacing: card.tokenSet.type.small.letterSpacing
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onEntered: card.hovered(card.index)
            onClicked: card.activate()
        }
    }

    Row {
        id: favoriteRow
        height: implicitHeight
        spacing: root.tokens.spacing.small

        Repeater {
            model: root.entries
            delegate: FavoriteCard {
                tokenSet: root.tokens
                cellWidth: root.cellWidth
                currentIndex: root.selectedIndex
                onPicked: function(entryId) { root.activated(entryId) }
                onHovered: function(index) { root.hovered(index) }
            }
        }
    }
}
