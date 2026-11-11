import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.



import QtQuick

Item {
    readonly property var nayoriRotatingDate: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property string style: nayoriRotatingDate.config.options.background.widgets.clock_cookie.dateStyle
    property color color: nayoriRotatingDate.colors.textColorOnBg
    property real angleStep: 12 * Math.PI / 180
    property string dateText: Qt.locale().toString(nayoriRotatingDate.dateTime.clock.date, "ddd dd")

    readonly property int clockSecond: nayoriRotatingDate.dateTime.clock.seconds
    readonly property string dialStyle: nayoriRotatingDate.config.options.background.widgets.clock_cookie.dialNumberStyle
    readonly property bool timeIndicators: nayoriRotatingDate.config.options.background.widgets.clock_cookie.timeIndicators

    property real radius: style === "border" ? 90 : 0
    Behavior on radius {
        NumberAnimation { duration: nayoriRotatingDate.motionDuration; easing.type: Easing.OutCubic }
    }

    rotation: {
        if (!nayoriRotatingDate.config.options.time.secondPrecision) return 0
        else return (360 / 60 * clockSecond) + 180 - (angleStep / Math.PI * 180 * dateText.length) / 2
    }

    Repeater {
        model: root.dateText.length

        delegate: Text {
            required property int index
            property real angle: index * root.angleStep - Math.PI / 2
            x: root.width / 2 + root.radius * Math.cos(angle) - width / 2
            y: root.height / 2 + root.radius * Math.sin(angle) - height / 2
            rotation: angle * 180 / Math.PI + 90

            color: root.color
            font {
                family: nayoriRotatingDate.appearance.font.family.title
                pixelSize: 30
                variableAxes: nayoriRotatingDate.appearance.font.variableAxes.title
            }

            text: root.dateText.charAt(index)
        }
    }
}
