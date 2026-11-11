import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects






AbstractBackgroundWidget {
    readonly property var nayoriResourceFillCardsWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "resource_fill_cards"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriResourceFillCardsWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriResourceFillCardsWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property bool enableCpu: nayoriResourceFillCardsWidget.config.options.background.widgets.resource_fill_cards?.enableCpu ?? true
    readonly property bool enableRam: nayoriResourceFillCardsWidget.config.options.background.widgets.resource_fill_cards?.enableRam ?? true
    readonly property bool enableDisk: nayoriResourceFillCardsWidget.config.options.background.widgets.resource_fill_cards?.enableDisk ?? true
    property bool _temperatureMetricRequested: false
    property bool _diskMetricRequested: false

    function syncResourceMetricRequests() {
        const visibleWidget = root.visible && !root.isPreview;
        const wantTemperature = visibleWidget && root.enableCpu;
        const wantDisk = visibleWidget && root.enableDisk;
        if (_temperatureMetricRequested !== wantTemperature) {
            nayoriResourceFillCardsWidget.resourceUsage.requestMetric("temperature", wantTemperature);
            _temperatureMetricRequested = wantTemperature;
        }
        if (_diskMetricRequested !== wantDisk) {
            nayoriResourceFillCardsWidget.resourceUsage.requestMetric("disk", wantDisk);
            _diskMetricRequested = wantDisk;
        }
    }

    Component.onCompleted: syncResourceMetricRequests()
    Component.onDestruction: {
        if (_temperatureMetricRequested)
            nayoriResourceFillCardsWidget.resourceUsage.requestMetric("temperature", false);
        if (_diskMetricRequested)
            nayoriResourceFillCardsWidget.resourceUsage.requestMetric("disk", false);
    }
    onVisibleChanged: syncResourceMetricRequests()
    onIsPreviewChanged: syncResourceMetricRequests()
    onEnableCpuChanged: syncResourceMetricRequests()
    onEnableDiskChanged: syncResourceMetricRequests()

    readonly property real contentScale: (nayoriResourceFillCardsWidget.config.options.background.widgets.resource_fill_cards?.widgetSize ?? 100) / 100.0
    readonly property string orientation: nayoriResourceFillCardsWidget.config.options.background.widgets.resource_fill_cards?.orientation ?? "horizontal"
    readonly property bool isHorizontal: orientation === "horizontal"

    readonly property var activeItems: {
        let list = [];
        if (enableCpu) list.push("cpu");
        if (enableRam) list.push("ram");
        if (enableDisk) list.push("disk");
        if (list.length === 0) list.push("cpu");
        return list;
    }

    readonly property int itemCount: activeItems.length

    implicitWidth: (isHorizontal ? itemCount * 240 : 240) * contentScale
    implicitHeight: (isHorizontal ? 240 : itemCount * 240) * contentScale

    StyledRectangularShadow {
        id: bgShadow
        target: outerCardBg
        visible: nayoriResourceFillCardsWidget.config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: outerCardBg
        anchors.fill: parent
        color: nayoriResourceFillCardsWidget.colors.tintBackground(nayoriResourceFillCardsWidget.colors.cardBgColor)
        radius: nayoriResourceFillCardsWidget.appearance.rounding.windowRounding

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: outerCardBg.width
                height: outerCardBg.height
                radius: outerCardBg.radius
                antialiasing: true
            }
        }

        GridLayout {
            anchors.fill: parent
            anchors.margins: 10 * root.contentScale
            columnSpacing: 10 * root.contentScale
            rowSpacing: 10 * root.contentScale
            columns: root.isHorizontal ? root.itemCount : 1
            rows: root.isHorizontal ? 1 : root.itemCount

            Repeater {
                model: root.activeItems

                delegate: Item {
                    id: cardItem
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    required property string modelData

                    readonly property real rawFillLevel: {
                        if (modelData === "cpu") return nayoriResourceFillCardsWidget.resourceUsage.cpuUsage;
                        if (modelData === "ram") return nayoriResourceFillCardsWidget.resourceUsage.memoryUsedPercentage;
                        if (modelData === "disk") return nayoriResourceFillCardsWidget.resourceUsage.diskUsedPercentage;
                        return 0;
                    }
                    readonly property real fillLevel: isFinite(rawFillLevel) ? Math.max(0, Math.min(1, rawFillLevel)) : 0
                    readonly property color accentColor: {
                        if (modelData === "cpu") return nayoriResourceFillCardsWidget.colors.colors.colPrimary;
                        if (modelData === "ram") return nayoriResourceFillCardsWidget.colors.colors.colSecondary;
                        if (modelData === "disk") return nayoriResourceFillCardsWidget.colors.colors.colTertiary;
                        return nayoriResourceFillCardsWidget.colors.colors.colPrimary;
                    }
                    readonly property color containerColor: {
                        if (modelData === "cpu") return nayoriResourceFillCardsWidget.colors.colors.colPrimaryContainer;
                        if (modelData === "ram") return nayoriResourceFillCardsWidget.colors.colors.colSecondaryContainer;
                        if (modelData === "disk") return nayoriResourceFillCardsWidget.colors.colors.colTertiaryContainer;
                        return nayoriResourceFillCardsWidget.colors.colors.colPrimaryContainer;
                    }
                    readonly property string cardSymbol: {
                        if (modelData === "cpu") return "memory";
                        if (modelData === "ram") return "memory_alt";
                        if (modelData === "disk") return "hard_drive";
                        return "memory";
                    }
                    readonly property string cardTitle: {
                        if (modelData === "cpu") return nayoriResourceFillCardsWidget.translation.tr("CPU Usage");
                        if (modelData === "ram") return nayoriResourceFillCardsWidget.translation.tr("RAM Memory");
                        if (modelData === "disk") return nayoriResourceFillCardsWidget.translation.tr("Disk Storage");
                        return "Resource";
                    }
                    readonly property string cardSubtitle: {
                        if (!isFinite(rawFillLevel)) return "—";
                        if (modelData === "cpu") {
                            let temp = nayoriResourceFillCardsWidget.resourceUsage.cpuTemp;
                            return temp > 0 ? (Math.round(temp) + "°C Thermal") : nayoriResourceFillCardsWidget.translation.tr("Processor Total");
                        }
                        if (modelData === "ram") {
                            let ramUsedGb = (nayoriResourceFillCardsWidget.resourceUsage.memoryUsed / (1024 * 1024)).toFixed(1);
                            let ramTotalGb = (nayoriResourceFillCardsWidget.resourceUsage.memoryTotal / (1024 * 1024)).toFixed(1);
                            return `${ramUsedGb} / ${ramTotalGb} GB`;
                        }
                        if (modelData === "disk") {
                            let diskUsedGb = (nayoriResourceFillCardsWidget.resourceUsage.diskUsed / (1024 * 1024 * 1024)).toFixed(0);
                            let diskTotalGb = (nayoriResourceFillCardsWidget.resourceUsage.diskTotal / (1024 * 1024 * 1024)).toFixed(0);
                            return `${diskUsedGb} / ${diskTotalGb} GB`;
                        }
                        return "";
                    }
                    readonly property string cardValueText: {
                        if (!isFinite(rawFillLevel)) return "—";
                        if (modelData === "cpu") return Math.round(nayoriResourceFillCardsWidget.resourceUsage.cpuUsage * 100) + "%";
                        if (modelData === "ram") return Math.round(nayoriResourceFillCardsWidget.resourceUsage.memoryUsedPercentage * 100) + "%";
                        if (modelData === "disk") return Math.round(nayoriResourceFillCardsWidget.resourceUsage.diskUsedPercentage * 100) + "%";
                        return "0%";
                    }

                    Rectangle {
                        id: cardInnerBg
                        anchors.fill: parent
                        color: nayoriResourceFillCardsWidget.colors.tintBackground(cardItem.containerColor)
                        radius: Math.max(0, nayoriResourceFillCardsWidget.appearance.rounding.windowRounding - (4 * root.contentScale))

                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: cardInnerBg.width
                                height: cardInnerBg.height
                                radius: cardInnerBg.radius
                                antialiasing: true
                            }
                        }

                        // Bottom Liquid Fill Level Indicator
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * Math.min(1.0, Math.max(0.0, cardItem.fillLevel))
                            color: nayoriResourceFillCardsWidget.colorUtils.applyAlpha(cardItem.accentColor, 0.30)

                            Behavior on height {
                                NumberAnimation { duration: (nayoriResourceFillCardsWidget.reducedMotion ? 0 : 400); easing.type: Easing.OutCubic }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.contentScale
                            spacing: 0

                            // Top Badge Icon Container
                            Rectangle {
                                Layout.preferredWidth: 54 * root.contentScale
                                Layout.preferredHeight: 54 * root.contentScale
                                radius: width / 2
                                color: nayoriResourceFillCardsWidget.colors.colors.colSurfaceContainerHighest
                                opacity: 0.95

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: cardItem.cardSymbol
                                    iconSize: 28 * root.contentScale
                                    color: nayoriResourceFillCardsWidget.colors.colors.colOnSurfaceVariant
                                }
                            }

                            Item { Layout.fillHeight: true }

                            // Metric Title & Subtitle Text
                            StyledText {
                                Layout.fillWidth: true
                                text: cardItem.cardTitle
                                font.pixelSize: 17 * root.contentScale
                                font.weight: Font.DemiBold
                                color: cardItem.accentColor
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: cardItem.cardSubtitle
                                font.pixelSize: 15 * root.contentScale
                                font.weight: Font.Normal
                                color: nayoriResourceFillCardsWidget.colorUtils.applyAlpha(cardItem.accentColor, 0.80)
                                elide: Text.ElideRight
                            }

                            // Large Fill Value Text
                            Text {
                                Layout.topMargin: 4 * root.contentScale
                                text: cardItem.cardValueText
                                color: cardItem.accentColor
                                font {
                                    pixelSize: 42 * root.contentScale
                                    weight: Font.Black
                                    bold: true
                                    family: "Google Sans Flex"
                                    variableAxes: ({ "wght": 900 })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
