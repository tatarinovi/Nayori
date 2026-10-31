pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

// Одна строка результата: значок, название, описание и стрелка действия.
// Выбранная строка получает подложку и «ввод», остальные — стрелку «дальше».
Item {
    id: row

    required property var tokenSet
    property string title: ""
    property string subtitle: ""
    property string iconSource: ""
    // Нарисованный значок вместо значка темы (например, поиск в интернете).
    property string glyph: ""
    // Короткая подпись типа: приложение, файл, папка, команда, интернет.
    property string typeLabel: ""
    // Команда рисуется отдельно от файлов и приложений.
    property bool distinct: false
    property bool selected: false
    // Тонкий разделитель под строкой. Хост гасит его рядом с выбранной строкой.
    property bool separator: false

    signal picked()
    signal hovered()

    readonly property int iconSize: 28
    readonly property bool showLetter: row.glyph === ""
        && (row.iconSource === "" || iconImage.status === Image.Error)
    readonly property color mutedInk: Qt.alpha(row.tokenSet.color.textMuted, 0.7)

    height: row.subtitle.length > 0 ? 54 : 46

    Accessible.role: Accessible.Button
    Accessible.name: {
        const label = row.typeLabel
        if (row.distinct && row.subtitle.length > 0)
            return (label.length > 0 ? label + " " : "") + row.title + ". " + row.subtitle
        if (label.length > 0)
            return label + " " + row.title
        return row.title
    }
    Accessible.onPressAction: row.picked()

    function monogram(name) {
        const text = String(name === undefined || name === null ? "" : name).trim()
        if (text.length === 0)
            return ""
        return text.charAt(0).toUpperCase()
    }

    Rectangle {
        x: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 18
        radius: 1
        visible: row.distinct
        color: row.tokenSet.color.secondary
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: row.tokenSet.radius.medium
        color: row.selected ? row.tokenSet.color.surfaceAlt : "transparent"
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: row.tokenSet.motion.off ? 0 : row.tokenSet.motion.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: row.tokenSet.spacing.medium
        anchors.rightMargin: row.tokenSet.spacing.medium
        height: 1
        visible: row.separator
        color: Qt.alpha(row.tokenSet.color.border, 0.4)
    }

    Item {
        id: glyphSlot
        x: row.tokenSet.spacing.medium - 2
        anchors.verticalCenter: parent.verticalCenter
        width: row.iconSize
        height: row.iconSize

        IconImage {
            id: iconImage
            anchors.fill: parent
            implicitSize: row.iconSize
            visible: row.glyph === "" && row.iconSource !== "" && status !== Image.Error
            source: row.glyph === "" ? row.iconSource : ""
            asynchronous: true
            mipmap: true
        }

        LauncherGlyph {
            anchors.centerIn: parent
            width: 24
            height: 24
            visible: row.glyph !== ""
            kind: row.glyph === "" ? "search" : row.glyph
            ink: row.tokenSet.color.text
        }

        Text {
            id: letter
            anchors.centerIn: parent
            visible: row.showLetter && text.length > 0
            text: row.monogram(row.title)
            color: row.tokenSet.color.text
            font.family: row.tokenSet.type.body.family
            font.pixelSize: row.tokenSet.type.body.size + 4
            font.weight: row.tokenSet.type.body.weight
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }

    LauncherGlyph {
        id: mark
        anchors.right: parent.right
        anchors.rightMargin: row.tokenSet.spacing.medium + 2
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        kind: row.selected ? "enter" : "next"
        ink: row.selected ? row.tokenSet.color.text : row.mutedInk
    }

    Text {
        id: typeText
        visible: row.typeLabel.length > 0
        anchors.right: mark.left
        anchors.rightMargin: row.tokenSet.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        text: row.typeLabel
        color: row.distinct ? row.tokenSet.color.secondary : row.mutedInk
        font.family: row.tokenSet.type.small.family
        font.pixelSize: row.tokenSet.type.small.size - 1
        font.weight: row.tokenSet.type.small.weight
        font.letterSpacing: row.tokenSet.type.small.letterSpacing
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }

    Column {
        id: words
        anchors.left: glyphSlot.right
        anchors.leftMargin: row.tokenSet.spacing.medium
        anchors.right: typeText.visible ? typeText.left : mark.left
        anchors.rightMargin: row.tokenSet.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: words.width
            text: row.title
            color: row.tokenSet.color.text
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: row.tokenSet.type.body.family
            font.pixelSize: row.tokenSet.type.body.size + 2
            font.weight: row.tokenSet.type.body.weight
            font.letterSpacing: row.tokenSet.type.body.letterSpacing
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }

        Text {
            width: words.width
            visible: row.subtitle.length > 0
            text: row.subtitle
            color: row.mutedInk
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: row.tokenSet.type.small.family
            font.pixelSize: row.tokenSet.type.small.size - 1
            font.weight: row.tokenSet.type.small.weight
            font.letterSpacing: row.tokenSet.type.small.letterSpacing
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        // Только движение мыши: список, выросший под неподвижным курсором, не уводит выбор.
        onPositionChanged: row.hovered()
        onPressed: row.hovered()
        onClicked: row.picked()
    }
}
