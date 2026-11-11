import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.





import QtQuick

Column {
    readonly property var nayoriTimeColumn: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property list<string> clockNumbers: nayoriTimeColumn.dateTime.time.split(/[: ]/)
    property bool isEnabled: nayoriTimeColumn.config.options.background.widgets.clock_cookie.timeIndicators
    property color color: nayoriTimeColumn.colors.highlightCircleColor

    property bool hourMarksEnabled: nayoriTimeColumn.config.options.background.widgets.clock_cookie.hourMarks
    spacing: -16

    Repeater {
        model: root.clockNumbers

        delegate: StyledText {
            required property string modelData
            text: modelData.padStart(2, "0")
            property bool isAmPm: !text.match(/\d{2}/i)
            property real numberSizeWithoutGlow: isAmPm ? 26 : 68
            property real numberSizeWithGlow: isAmPm ? 20 : 40
            property real numberSize: root.hourMarksEnabled ? numberSizeWithGlow : numberSizeWithoutGlow

            anchors.horizontalCenter: root.horizontalCenter
            color: root.color
            font {
                family: nayoriTimeColumn.appearance.font.family.numbers
                weight: Font.Bold
                pixelSize: numberSize
                variableAxes: ({ "wght": 900 })
            }

            Behavior on numberSize {
                NumberAnimation { duration: nayoriTimeColumn.motionDuration; easing.type: Easing.OutCubic }
            }
        }
    }
}
