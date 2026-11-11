import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.




import QtQuick
import QtQuick.Layouts

ColumnLayout {
    readonly property var nayoriDigitalClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: clockColumn
    spacing: 4

    readonly property bool colorful: nayoriDigitalClock.config.options.background.widgets.clock_digital.colorful
    readonly property bool showColon: nayoriDigitalClock.config.options.background.widgets.clock_digital.showColon
    readonly property bool showSeconds: nayoriDigitalClock.config.options.background.widgets.clock_digital.showSeconds ?? false
    readonly property real lineSpacing: nayoriDigitalClock.config.options.background.widgets.clock_digital.lineSpacing

    property bool isVertical: nayoriDigitalClock.config.options.background.widgets.clock_digital.vertical
    property color colText: nayoriDigitalClock.colors.textColorOnBg
    property color colTextSecondary: nayoriDigitalClock.colors.subtextColorOnBg
    property color colTextTertiary: nayoriDigitalClock.colors.accentColor
    property var textHorizontalAlignment: Text.AlignHCenter

    // Time
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: false
        ClockText {
            id: timeTextTop
            text: nayoriDigitalClock.dateTime.time.split(":")[0].padStart(2, "0")
            color: clockColumn.colText
            horizontalAlignment: Text.AlignHCenter
            font {
                pixelSize: nayoriDigitalClock.config.options.background.widgets.clock_digital.font.size
                weight: nayoriDigitalClock.config.options.background.widgets.clock_digital.font.weight
                family: nayoriDigitalClock.appearance.font.family.numbers
                variableAxes: ({
                        "wdth": nayoriDigitalClock.config.options.background.widgets.clock_digital.font.width,
                        "ROND": nayoriDigitalClock.config.options.background.widgets.clock_digital.font.roundness
                    })
            }
        }
        Loader {
            active: !clockColumn.isVertical && showColon
            visible: active
            sourceComponent: ClockText {
                text: ":"
                color: colorful ? clockColumn.colTextSecondary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
        Loader {
            active: !clockColumn.isVertical
            visible: active
            sourceComponent: ClockText {
                text: nayoriDigitalClock.dateTime.time.split(":")[1].split(" ")[0].padStart(2, "0")
                color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
        Loader {
            active: !clockColumn.isVertical && clockColumn.showSeconds && showColon
            visible: active
            sourceComponent: ClockText {
                text: ":"
                color: colorful ? clockColumn.colTextSecondary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
        Loader {
            active: !clockColumn.isVertical && clockColumn.showSeconds
            visible: active
            sourceComponent: ClockText {
                text: nayoriDigitalClock.dateTime.seconds
                color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
    }


    Loader {
        // -40 is the built-in tightening of the stacked lines; lineSpacing is
        // the user's vertical gap delta on top of it (negative overlaps).
        Layout.topMargin: -40 + clockColumn.lineSpacing
        Layout.fillWidth: true
        active: clockColumn.isVertical
        visible: active
        sourceComponent: ClockText {
            id: timeTextBottom
            text: nayoriDigitalClock.dateTime.time.split(":")[1].split(" ")[0].padStart(2, "0") + (clockColumn.showSeconds ? ":" + nayoriDigitalClock.dateTime.seconds : "")
            color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
            horizontalAlignment: clockColumn.textHorizontalAlignment
            font {
                pixelSize: timeTextTop.font.pixelSize
                weight: timeTextTop.font.weight
                family: timeTextTop.font.family
                variableAxes: timeTextTop.font.variableAxes
            }
        }
    }

    // Date
    ClockText {
        visible: nayoriDigitalClock.config.options.background.widgets.clock_digital.showDate
        Layout.topMargin: -20
        Layout.fillWidth: true
        text: nayoriDigitalClock.dateTime.longDate
        color: colorful ? clockColumn.colTextSecondary : clockColumn.colText
        horizontalAlignment: clockColumn.textHorizontalAlignment
    }

    // Quote
    ClockText {
        visible: nayoriDigitalClock.config.options.background.widgets.clock_digital.quoteEnable && nayoriDigitalClock.config.options.background.widgets.clock_digital.quoteText.length > 0
        font.pixelSize: Math.round(nayoriDigitalClock.appearance.font.pixelSize.normal)
        text: nayoriDigitalClock.config.options.background.widgets.clock_digital.quoteText
        animateChange: false
        color: clockColumn.colTextSecondary
        horizontalAlignment: clockColumn.textHorizontalAlignment
    }
}
