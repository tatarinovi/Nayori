import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io






AbstractBackgroundWidget {
    readonly property var nayoriRamPillWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "resource_ram_pill"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriRamPillWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriRamPillWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriRamPillWidget.config.options.background.widgets.resource_ram_pill
    readonly property real contentScale: (options?.widgetSize ?? 100) / 100.0
    readonly property string aspectRatio: options?.aspectRatio ?? "2x0.5"
    readonly property bool showDetails: options?.showDetails ?? true
    readonly property bool isWide: aspectRatio === "2x0.5"
    readonly property real innerMargin: 4 * contentScale
    readonly property real innerRadius: Math.max(0, nayoriRamPillWidget.appearance.rounding.windowRounding - innerMargin)

    implicitWidth: (isWide ? 480 : 240) * contentScale
    implicitHeight: 60 * contentScale

    readonly property real ramUsagePct: nayoriRamPillWidget.resourceUsage.memoryUsedPercentage
    readonly property string ramUsedGb: (nayoriRamPillWidget.resourceUsage.memoryUsed / (1024 * 1024)).toFixed(1)
    readonly property string ramTotalGb: (nayoriRamPillWidget.resourceUsage.memoryTotal / (1024 * 1024)).toFixed(1)

    readonly property string titleText: {
        if (root.isWide && root.showDetails)
            return nayoriRamPillWidget.translation.tr("RAM") + " · " + root.ramUsedGb + "/" + root.ramTotalGb + " GB";
        if (root.isWide)
            return nayoriRamPillWidget.translation.tr("RAM Usage");
        return nayoriRamPillWidget.translation.tr("RAM");
    }
    readonly property string valueText: Math.round(root.ramUsagePct * 100) + "%"

    Rectangle {
        anchors.fill: parent
        radius: nayoriRamPillWidget.appearance.rounding.windowRounding
        color: nayoriRamPillWidget.colors.tintBackground(nayoriRamPillWidget.colors.cardBgColor)

        Item {
            anchors.fill: parent
            anchors.margins: root.innerMargin

            Rectangle {
                id: bgTrack
                anchors.fill: parent
                radius: root.innerRadius
                color: nayoriRamPillWidget.colors.pillBgColor

                layer.enabled: true
                layer.samples: 4
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: bgTrack.width
                        height: bgTrack.height
                        radius: bgTrack.radius
                    }
                }

                // ── Track Text Layer (Unfilled side) ──
                RowLayout {
                    id: trackTextRow
                    anchors.fill: parent
                    anchors.leftMargin: 16 * root.contentScale
                    anchors.rightMargin: 16 * root.contentScale
                    spacing: 10 * root.contentScale

                    MaterialSymbol {
                        text: "memory_alt"
                        iconSize: 18 * root.contentScale
                        color: nayoriRamPillWidget.colors.textColorOnPillTrack
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: root.titleText
                        font.pixelSize: Math.round(13 * root.contentScale)
                        font.weight: Font.Bold
                        font.family: nayoriRamPillWidget.appearance.font.family.main
                        color: nayoriRamPillWidget.colors.textColorOnPillTrack
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: root.valueText
                        font.pixelSize: Math.round(13 * root.contentScale)
                        font.weight: Font.Bold
                        font.family: nayoriRamPillWidget.appearance.font.family.main
                        color: nayoriRamPillWidget.colors.textColorOnPillTrack
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ── Progress Fill Layer (Clipped overlay) ──
                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, parent.width * Math.min(1.0, Math.max(0.0, root.ramUsagePct)))
                    color: nayoriRamPillWidget.colors.pillFillColor
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: (nayoriRamPillWidget && nayoriRamPillWidget.reducedMotion ? 0 : 350)
                            easing.type: Easing.OutCubic
                        }
                    }

                    RowLayout {
                        width: bgTrack.width
                        height: bgTrack.height
                        anchors.left: progressFill.left
                        anchors.leftMargin: 16 * root.contentScale
                        spacing: 10 * root.contentScale

                        MaterialSymbol {
                            text: "memory_alt"
                            iconSize: 18 * root.contentScale
                            color: nayoriRamPillWidget.colors.textColorOnPillFill
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: root.titleText
                            font.pixelSize: Math.round(13 * root.contentScale)
                            font.weight: Font.Bold
                            font.family: nayoriRamPillWidget.appearance.font.family.main
                            color: nayoriRamPillWidget.colors.textColorOnPillFill
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: root.valueText
                            font.pixelSize: Math.round(13 * root.contentScale)
                            font.weight: Font.Bold
                            font.family: nayoriRamPillWidget.appearance.font.family.main
                            color: nayoriRamPillWidget.colors.textColorOnPillFill
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
