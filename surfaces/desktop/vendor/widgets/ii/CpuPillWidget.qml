import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io






AbstractBackgroundWidget {
    readonly property var nayoriCpuPillWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "resource_cpu_pill"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriCpuPillWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriCpuPillWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriCpuPillWidget.config.options.background.widgets.resource_cpu_pill
    readonly property real contentScale: (options?.widgetSize ?? 100) / 100.0
    readonly property string aspectRatio: options?.aspectRatio ?? "2x0.5"
    readonly property bool showDetails: options?.showDetails ?? true
    readonly property bool isWide: aspectRatio === "2x0.5"
    readonly property real innerMargin: 4 * contentScale
    readonly property real innerRadius: Math.max(0, nayoriCpuPillWidget.appearance.rounding.windowRounding - innerMargin)

    implicitWidth: (isWide ? 480 : 240) * contentScale
    implicitHeight: 60 * contentScale

    readonly property real cpuUsage: nayoriCpuPillWidget.resourceUsage.cpuUsage
    readonly property real cpuTemp: nayoriCpuPillWidget.resourceUsage.cpuTemp
    property bool _temperatureMetricRequested: false

    function syncTemperatureMetricRequest() {
        const wanted = root.visible && !root.isPreview;
        if (_temperatureMetricRequested === wanted)
            return;
        nayoriCpuPillWidget.resourceUsage.requestMetric("temperature", wanted);
        _temperatureMetricRequested = wanted;
    }

    Component.onCompleted: syncTemperatureMetricRequest()
    Component.onDestruction: {
        if (_temperatureMetricRequested)
            nayoriCpuPillWidget.resourceUsage.requestMetric("temperature", false);
    }
    onVisibleChanged: syncTemperatureMetricRequest()
    onIsPreviewChanged: syncTemperatureMetricRequest()

    readonly property string titleText: {
        if (root.isWide && root.showDetails && root.cpuTemp > 0)
            return nayoriCpuPillWidget.translation.tr("CPU Usage") + " · " + Math.round(root.cpuTemp) + "°C";
        if (root.isWide)
            return nayoriCpuPillWidget.translation.tr("CPU Usage");
        return nayoriCpuPillWidget.translation.tr("CPU");
    }
    readonly property string valueText: Math.round(root.cpuUsage * 100) + "%"

    Rectangle {
        anchors.fill: parent
        radius: nayoriCpuPillWidget.appearance.rounding.windowRounding
        color: nayoriCpuPillWidget.colors.tintBackground(nayoriCpuPillWidget.colors.cardBgColor)

        Item {
            anchors.fill: parent
            anchors.margins: root.innerMargin

            Rectangle {
                id: bgTrack
                anchors.fill: parent
                radius: root.innerRadius
                color: nayoriCpuPillWidget.colors.pillBgColor

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
                        text: "memory"
                        iconSize: 18 * root.contentScale
                        color: nayoriCpuPillWidget.colors.textColorOnPillTrack
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: root.titleText
                        font.pixelSize: Math.round(13 * root.contentScale)
                        font.weight: Font.Bold
                        font.family: nayoriCpuPillWidget.appearance.font.family.main
                        color: nayoriCpuPillWidget.colors.textColorOnPillTrack
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: root.valueText
                        font.pixelSize: Math.round(13 * root.contentScale)
                        font.weight: Font.Bold
                        font.family: nayoriCpuPillWidget.appearance.font.family.main
                        color: nayoriCpuPillWidget.colors.textColorOnPillTrack
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                // ── Progress Fill Layer (Clipped overlay) ──
                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, parent.width * Math.min(1.0, Math.max(0.0, root.cpuUsage)))
                    color: nayoriCpuPillWidget.colors.pillFillColor
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: (nayoriCpuPillWidget && nayoriCpuPillWidget.reducedMotion ? 0 : 350)
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
                            text: "memory"
                            iconSize: 18 * root.contentScale
                            color: nayoriCpuPillWidget.colors.textColorOnPillFill
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: root.titleText
                            font.pixelSize: Math.round(13 * root.contentScale)
                            font.weight: Font.Bold
                            font.family: nayoriCpuPillWidget.appearance.font.family.main
                            color: nayoriCpuPillWidget.colors.textColorOnPillFill
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: root.valueText
                            font.pixelSize: Math.round(13 * root.contentScale)
                            font.weight: Font.Bold
                            font.family: nayoriCpuPillWidget.appearance.font.family.main
                            color: nayoriCpuPillWidget.colors.textColorOnPillFill
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
