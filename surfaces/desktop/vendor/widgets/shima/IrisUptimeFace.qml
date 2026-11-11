import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts



IrisWidgetFace {
    readonly property var nayoriIrisUptimeFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property int total: root.widget.sessionSeconds
    readonly property int days: Math.floor(root.total / 86400)
    readonly property int hours: Math.floor(root.total % 86400 / 3600)
    readonly property int minutes: Math.floor(root.total % 3600 / 60)
    readonly property var parts: root.days > 0
        ? [{ value: root.days, unit: nayoriIrisUptimeFace.translation.tr("d") }, { value: root.hours, unit: nayoriIrisUptimeFace.translation.tr("h") }]
        : [{ value: root.hours, unit: nayoriIrisUptimeFace.translation.tr("h") }, { value: root.minutes, unit: nayoriIrisUptimeFace.translation.tr("min") }]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "timelapse"
            text: nayoriIrisUptimeFace.translation.tr("Uptime")
        }
        Item { Layout.fillHeight: true }
        Row {
            spacing: root.dp(6)
            Repeater {
                model: root.parts
                Row {
                    id: part
                    required property var modelData
                    spacing: root.dp(2)
                    FaceFigure {
                        id: figure
                        face: root
                        text: part.modelData.value
                        size: 38
                    }
                    FaceText {
                        face: root
                        anchors.baseline: figure.baseline
                        text: part.modelData.unit
                        color: root.inkSecondary
                        size: 15
                        weight: Font.DemiBold
                    }
                }
            }
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.widget.showSince
            text: nayoriIrisUptimeFace.translation.tr("Since %1").arg(root.widget.bootLabel)
            color: root.inkSecondary
            size: 12.5
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            visible: root.widget.showBreakdown && root.widget.sessionDay > 1
            text: nayoriIrisUptimeFace.translation.tr("Day %1 of this session").arg(root.widget.sessionDay)
            color: root.inkTertiary
            size: 11.5
        }
    }
}
