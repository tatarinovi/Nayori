pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "WidgetLayout.js" as WidgetLayout

FocusScope {
    id: root
    required property var tokens
    property var spec: null
    property bool editing: false
    property bool snap: true
    property int screenWidth: 0
    property int screenHeight: 0
    property date now: new Date()
    property var weatherService: null
    property var music: null
    property var systemReader: null
    property string focusId: ""
    signal commitPosition(string id, real x, real y, bool useSnap)
    signal removeRequested(string id)
    signal noteEdited(string id, string text)
    signal maskDirty()

    readonly property var box: spec ? WidgetLayout.sizeOf(spec) : ({ width: 0, height: 0 })
    readonly property bool card: spec && spec.style === "card"
    readonly property bool takesInput: {
        if (!spec)
            return false
        if (editing)
            return true
        if (spec.type === "note")
            return true
        if (spec.type === "music")
            return !!(music && music.player)
        return false
    }
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    function widgetName(type) {
        if (type === "clock")
            return "Часы"
        if (type === "weather")
            return "Погода"
        if (type === "music")
            return "Музыка"
        if (type === "system")
            return "Система"
        if (type === "note")
            return "Заметка"
        return "Виджет"
    }

    visible: spec !== null
    width: box.width
    height: box.height
    x: !spec ? 0 : dragging ? dragX : spec.x
    y: !spec ? 0 : dragging ? dragY : spec.y
    z: dragging ? 10 : 0
    objectName: spec ? "desktop-widget-" + spec.id : "desktop-widget"
    activeFocusOnTab: editing
    Accessible.name: spec ? widgetName(spec.type) : "Виджет"
    Accessible.description: editing ? "Стрелки двигают виджет" : ""

    onTakesInputChanged: maskDirty()
    onSpecChanged: if (spec && editing && focusId === spec.id && !activeFocus) forceActiveFocus()
    Component.onCompleted: {
        maskDirty()
        if (spec && editing && focusId === spec.id)
            forceActiveFocus()
    }
    onActiveFocusChanged: if (activeFocus && spec) focusId = spec.id

    Keys.onPressed: function(event) {
        if (!editing || !spec || activeFocusItem !== root)
            return
        const grid = WidgetLayout.gridSize()
        const fine = event.modifiers & Qt.ShiftModifier
        const step = fine ? (snap ? 1 : grid) : (snap ? grid : 1)
        if (event.key === Qt.Key_Left)
            commitPosition(spec.id, x - step, y, false)
        else if (event.key === Qt.Key_Right)
            commitPosition(spec.id, x + step, y, false)
        else if (event.key === Qt.Key_Up)
            commitPosition(spec.id, x, y - step, false)
        else if (event.key === Qt.Key_Down)
            commitPosition(spec.id, x, y + step, false)
        else if (event.key === Qt.Key_Delete)
            removeRequested(spec.id)
        else
            return
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.medium
        color: root.card ? root.tokens.material.dense : "transparent"
        border.width: root.card || root.editing ? 1 : 0
        border.color: root.editing && (root.activeFocus || root.dragging) ? root.tokens.color.accent : root.tokens.color.border
        antialiasing: true
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.editing && root.spec !== null
        acceptedButtons: Qt.LeftButton
        hoverEnabled: enabled
        preventStealing: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real startX: 0
        property real startY: 0
        property real pressX: 0
        property real pressY: 0
        onPressed: function(mouse) {
            const scene = mapToItem(root.parent, mouse.x, mouse.y)
            pressX = scene.x
            pressY = scene.y
            startX = root.x
            startY = root.y
            root.forceActiveFocus()
            mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            const scene = mapToItem(root.parent, mouse.x, mouse.y)
            const nx = startX + scene.x - pressX
            const ny = startY + scene.y - pressY
            if (!root.dragging && Math.abs(nx - startX) < 4 && Math.abs(ny - startY) < 4)
                return
            root.dragging = true
            const maxX = Math.max(0, root.screenWidth - root.width)
            const maxY = Math.max(0, root.screenHeight - root.height)
            root.dragX = Math.min(maxX, Math.max(0, nx))
            root.dragY = Math.min(maxY, Math.max(0, ny))
        }
        onReleased: {
            if (root.dragging && root.spec)
                root.commitPosition(root.spec.id, root.dragX, root.dragY, root.snap)
            root.dragging = false
        }
        onCanceled: root.dragging = false
    }

    Item {
        id: content
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.card ? 12 : 0
        anchors.rightMargin: root.card ? 12 : 0
        anchors.bottomMargin: root.card ? 12 : 0
        anchors.topMargin: root.editing ? 40 : (root.card ? 12 : 0)
        clip: true

        ClockWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "clock"
            enabled: visible
            tokens: root.tokens
            now: root.now
            large: root.spec && root.spec.size === "large"
        }
        WeatherWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "weather"
            enabled: visible
            tokens: root.tokens
            service: root.weatherService
            large: root.spec && root.spec.size === "large"
        }
        MusicWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "music"
            enabled: visible
            tokens: root.tokens
            music: root.music
            large: root.spec && root.spec.size === "large"
        }
        SystemWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "system"
            enabled: visible
            tokens: root.tokens
            reader: root.systemReader
            large: root.spec && root.spec.size === "large"
        }
        NoteWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "note"
            enabled: visible
            tokens: root.tokens
            savedText: root.spec && root.spec.type === "note" && root.spec.text ? root.spec.text : ""
            onTextEdited: function(text) {
                if (root.spec)
                    root.noteEdited(root.spec.id, text)
            }
        }
    }

    AbstractButton {
        id: removeButton
        z: 3
        visible: root.editing && root.spec !== null
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        padding: 0
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        text: "Удалить"
        Accessible.name: "Удалить"
        Accessible.description: root.spec ? root.widgetName(root.spec.type) : ""
        implicitWidth: Math.max(76, contentItem.implicitWidth + 16)
        implicitHeight: 28
        onClicked: if (root.spec) root.removeRequested(root.spec.id)
        background: Rectangle {
            radius: root.tokens.radius.small
            color: removeButton.down || removeButton.hovered ? root.tokens.color.accentHover : root.tokens.color.surfaceAlt
            border.width: 1
            border.color: removeButton.visualFocus ? root.tokens.color.accent : root.tokens.color.border
        }
        contentItem: DesktopLabel {
            tokens: root.tokens
            text: removeButton.text
            font.pixelSize: root.tokens.type.small.size
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
