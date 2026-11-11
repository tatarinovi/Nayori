pragma ComponentBehavior: Bound
import QtQuick
import "../panel"

// Content only: DesktopWidgets owns placement, dismissal and the input layer.
FocusScope {
    id: root
    required property var tokens
    property bool opened: false
    property bool busy: false
    property url wallpaperSource: ""
    property string notice: ""
    signal requested(string action)
    signal dismissed()
    implicitWidth: 344
    implicitHeight: contents.implicitHeight + 16
    readonly property bool presenting: opened || opacity > 0
    visible: presenting
    enabled: opened
    opacity: opened ? 1 : 0
    scale: tokens.motion.off ? 1 : 0.97 + opacity * 0.03
    transformOrigin: Item.TopLeft
    Behavior on opacity { NumberAnimation { id: fade; duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.OutCubic } }
    Connections {
        target: root.tokens.motion
        function onOffChanged() { if (root.tokens.motion.off) fade.complete() }
    }
    onOpenedChanged: if (opened) Qt.callLater(() => {
        if (root.opened) quick.itemAt(0).forceActiveFocus()
    })
    Keys.onEscapePressed: function(event) { root.dismissed(); event.accepted = true }
    function buttons() {
        const result = []
        for (const group of [quick, mainRows, power])
            for (let i = 0; i < group.count; i++) result.push(group.itemAt(i))
        return result
    }
    Keys.onPressed: function(event) {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) < 0) return
        const list = buttons()
        let current = list.findIndex(button => button.activeFocus)
        const step = event.key === Qt.Key_Left || event.key === Qt.Key_Up ? -1 : 1
        for (let i = 0; i < list.length; i++) {
            current = (current + step + list.length) % list.length
            if (list[current].enabled) { list[current].forceActiveFocus(Qt.TabFocusReason); break }
        }
        event.accepted = true
    }
    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.medium
        color: root.tokens.material.menu
        border.width: 1
        border.color: root.tokens.color.border
    }
    Column {
        id: contents
        x: 8; y: 8
        width: parent.width - 16
        spacing: 4
        Row {
            width: parent.width
            spacing: 4
            Repeater {
                id: quick
                model: [
                    { action: "wallpaper", text: "Обои", icon: "wallpaper" },
                    { action: "search", text: "Поиск", icon: "search" },
                    { action: "terminal", text: "Терминал", icon: "terminal" }
                ]
                delegate: MenuRow {
                    required property var modelData
                    objectName: "desktop-menu-" + modelData.action
                    tokens: root.tokens
                    width: (contents.width - 8) / 3
                    tile: true
                    iconOnly: true
                    frostedTile: true
                    backdropSource: modelData.action === "wallpaper" ? root.wallpaperSource : ""
                    text: modelData.text; glyph: modelData.icon
                    onClicked: root.requested(modelData.action)
                    onEscapePressed: root.dismissed()
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
        Repeater {
            id: mainRows
            model: [
                { action: "widgets", text: "Редактировать рабочий стол", icon: "apps" },
                { action: "settings", text: "Настройки", icon: "settings" }
            ]
            delegate: MenuRow {
                required property var modelData
                objectName: "desktop-menu-" + modelData.action
                tokens: root.tokens
                width: contents.width
                compact: true; showChevron: false
                emphasized: modelData.action === "widgets"
                text: modelData.text; glyph: modelData.icon
                onClicked: root.requested(modelData.action)
                onEscapePressed: root.dismissed()
            }
        }
        Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
        Row {
            width: parent.width
            spacing: 4
            Repeater {
                id: power
                model: [
                    { action: "lock", text: "Блокировка", icon: "lock" },
                    { action: "logout", text: "Выход", icon: "logout" },
                    { action: "reboot", text: "Перезагрузка", icon: "reboot" },
                    { action: "powerOff", text: "Выключение", icon: "power" }
                ]
                delegate: HoldMenuRow {
                    required property var modelData
                    objectName: "desktop-menu-" + modelData.action
                    tokens: root.tokens
                    width: (contents.width - 12) / 4
                    tile: true
                    iconOnly: true
                    text: modelData.text; glyph: modelData.icon
                    enabled: !root.busy
                    frostedTile: true
                    holdEnabled: root.opened
                    onHeld: root.requested(modelData.action)
                    onEscapePressed: root.dismissed()
                }
            }
        }
        DesktopLabel {
            width: parent.width
            tokens: root.tokens
            visible: root.notice !== ""
            text: root.notice
            wrapMode: Text.Wrap
        }
    }
}
