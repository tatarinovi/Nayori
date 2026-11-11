import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick




Row {
    readonly property var nayoriIrisClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property string text: nayoriIrisClock.dateTime.timeDisplay
    property real pixelSize: nayoriIrisClock.irisStyle.typeHeadline
    property int weight: nayoriIrisClock.irisStyle.figureWeight
    property color color: nayoriIrisClock.irisStyle.text
    property color separatorColor: nayoriIrisClock.irisStyle.frameAccent
    property string family: nayoriIrisClock.irisStyle.fontNumbers
    property real minorScale: 0.58

    readonly property var parts: {
        const raw = String(root.text ?? "").trim()
        const period = raw.match(/\s*([^\d:.\s]+)$/)
        const figure = period ? raw.slice(0, period.index) : raw
        const pieces = figure.split(/[:.]/)
        return {
            hours: pieces[0] ?? "",
            minutes: pieces[1] ?? "",
            seconds: pieces[2] ?? "",
            period: period ? period[1] : ""
        }
    }

    spacing: 0

    component Figure: Text {
        id: figure
        width: Math.ceil(implicitWidth)
        transform: Translate { x: Math.round(figure.x) - figure.x; y: Math.round(figure.y) - figure.y }
        font.family: root.family
        font.pixelSize: Math.round(root.pixelSize)
        font.weight: root.weight
        font.features: ({ "tnum": 1 })
        font.letterSpacing: Math.round(-root.pixelSize * 0.02)
        color: root.color
        renderType: Text.NativeRendering
    }

    component Minor: Text {
        id: minor
        width: Math.ceil(implicitWidth)
        transform: Translate { x: Math.round(minor.x) - minor.x; y: Math.round(minor.y) - minor.y }
        font.family: root.family
        font.pixelSize: Math.round(root.pixelSize * root.minorScale)
        font.weight: nayoriIrisClock.irisStyle.weight(Font.DemiBold)
        font.features: ({ "tnum": 1 })
        color: nayoriIrisClock.irisStyle.secondaryOf(root.color)
        renderType: Text.NativeRendering
    }

    component Count: IrisNumber {
        family: root.family
        pixelSize: root.pixelSize
        weight: root.weight
        letterSpacing: Math.round(-root.pixelSize * 0.02)
        color: root.color
    }

    Count { id: hoursText; text: root.parts.hours }
    Figure {
        text: ":"
        visible: root.parts.minutes.length > 0
        color: root.separatorColor
        anchors.baseline: hoursText.baseline
        anchors.baselineOffset: -Math.round(root.pixelSize * 0.06)
        leftPadding: Math.round(root.pixelSize * 0.03)
        rightPadding: Math.round(root.pixelSize * 0.03)
    }
    Count { text: root.parts.minutes; anchors.baseline: hoursText.baseline }
    Item {
        visible: root.parts.seconds.length > 0
        implicitWidth: Math.ceil(secondsText.implicitWidth + root.pixelSize * 0.12)
        implicitHeight: secondsText.implicitHeight
        baselineOffset: secondsText.baselineOffset
        anchors.baseline: hoursText.baseline
        IrisNumber {
            id: secondsText
            anchors.right: parent.right
            text: root.parts.seconds
            family: root.family
            pixelSize: Math.round(root.pixelSize * root.minorScale)
            weight: Font.DemiBold
            color: nayoriIrisClock.irisStyle.secondaryOf(root.color)
        }
    }
    Minor {
        visible: root.parts.period.length > 0
        text: root.parts.period
        leftPadding: Math.round(root.pixelSize * 0.16)
        anchors.baseline: hoursText.baseline
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
}
