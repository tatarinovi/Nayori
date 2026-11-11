import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick



IconButton {
    readonly property var nayoriCloseButton: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    size: 28
    cornerRadius: 8
    iconFontSize: 9
    buttonIcon: "󰅖"
    accentColor: nayoriCloseButton.pythonTheme.surface0
    textColor: nayoriCloseButton.pythonTheme.text
}
