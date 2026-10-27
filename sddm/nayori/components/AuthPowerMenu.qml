import QtQuick
import QtQuick.Controls

Menu {
    id: root
    required property var colors
    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false
    signal requested(string action)
    // Keep the menu inside the protected lock surface, without a new window.
    popupType: Popup.Item
    padding: 6
    font.family: "Inter"
    font.pixelSize: 14
    palette.window: colors.background
    palette.base: colors.background
    palette.text: colors.text
    palette.windowText: colors.text
    palette.highlight: colors.accent
    palette.highlightedText: colors.accentText
    background: Rectangle { radius: 12; color: root.colors.background; border.color: root.colors.border }
    MenuItem { implicitHeight: 44; objectName: "authPowerSuspend"; text: "Спящий режим"; enabled: root.canSuspend; onTriggered: root.requested("suspend") }
    MenuItem { implicitHeight: 44; objectName: "authPowerReboot"; text: "Перезагрузить"; enabled: root.canReboot; onTriggered: root.requested("reboot") }
    MenuItem { implicitHeight: 44; objectName: "authPowerOff"; text: "Выключить"; enabled: root.canPowerOff; onTriggered: root.requested("powerOff") }
}
