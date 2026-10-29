pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Window
import "../../services/system"

Column {
    id: root
    objectName: "wireguard-controls"
    required property var tokens
    property bool watching: false
    property alias control: control
    spacing: 8

    function reveal(item) {
        for (let view = root.parent; view; view = view.parent) {
            if (view.contentY === undefined || !view.contentItem || view.contentHeight === undefined)
                continue
            const point = item.mapToItem(view.contentItem, 0, 0)
            if (point.y < view.contentY)
                view.contentY = Math.max(0, point.y)
            else if (point.y + item.height > view.contentY + view.height)
                view.contentY = Math.max(0, Math.min(view.contentHeight - view.height, point.y + item.height - view.height))
            return
        }
    }

    WireGuardControl {
        id: control
        watching: root.watching && root.visible && (!root.Window.window || root.Window.window.visible)
    }
    FileDialog {
        id: importDialog
        title: "Импорт WireGuard"
        nameFilters: ["Конфигурация WireGuard (*.conf)"]
        fileMode: FileDialog.OpenFile
        onAccepted: control.importFile(selectedFile)
    }

    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        text: "WireGuard"
        font.family: root.tokens.type.display.family
        font.pixelSize: 18
    }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        visible: !control.ready || (control.available && control.profiles.length === 0)
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: !control.ready ? "Загрузка подключений…" : "Добавьте конфигурацию .conf от вашего VPN-провайдера или администратора сети"
    }
    Repeater {
        model: control.profiles
        delegate: SettingsAction {
            id: row
            required property var modelData
            readonly property bool pending: control.operationUuid === modelData.uuid
            tokens: root.tokens
            width: parent.width
            text: modelData.name
            detail: pending ? (control.operation === "up" ? "Подключение…" : "Отключение…")
                : modelData.state === "activating" ? "Подключение…"
                : modelData.state === "deactivating" ? "Отключение…"
                : modelData.active ? "Подключено" + (modelData.device ? " · " + modelData.device : "") + " · Отключить"
                : "Не подключено · Подключить"
            selected: modelData.active
            enabled: control.available && !control.busy && modelData.state !== "activating" && modelData.state !== "deactivating"
            onClicked: control.toggle(row.modelData)
            onActiveFocusChanged: if (activeFocus) root.reveal(row)
        }
    }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        visible: control.notice !== "" && control.error === ""
        text: control.notice
        color: root.tokens.color.textMuted
        font.pixelSize: 13
    }
    SettingsAction {
        id: importAction
        tokens: root.tokens
        width: parent.width
        text: control.operation === "import" ? "Импорт…" : "Импортировать .conf"
        enabled: control.ready && control.available && !control.busy
        onClicked: importDialog.open()
        onActiveFocusChanged: if (activeFocus) root.reveal(importAction)
    }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        visible: control.error !== ""
        text: control.error
        color: root.tokens.color.secondary
        font.pixelSize: 13
        Accessible.role: Accessible.AlertMessage
    }
    SettingsAction {
        id: refreshAction
        tokens: root.tokens
        width: parent.width
        visible: control.error !== ""
        text: "Обновить список"
        enabled: !control.busy
        onClicked: control.refresh(true)
        onActiveFocusChanged: if (activeFocus) root.reveal(refreshAction)
    }
}
