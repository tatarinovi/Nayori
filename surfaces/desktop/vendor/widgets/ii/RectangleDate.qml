import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.




import QtQuick

Rectangle {
    readonly property var nayoriRectangleDate: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: rect
    readonly property string dialStyle: nayoriRectangleDate.config.options.background.widgets.clock_cookie.dialNumberStyle

    StyledText {
        anchors.centerIn: parent
        color: nayoriRectangleDate.colors.accentColor
        text: Qt.locale().toString(nayoriRectangleDate.dateTime.clock.date, "dd")
        font {
            family: nayoriRectangleDate.appearance.font.family.expressive
            pixelSize: 20
            weight: 1000
        }
    }
}
