import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick





/*
 * Date Banner (2x1). An editorial card: the weekday as a headline that fills
 * the width, over a two-by-two grid of monospace captions and values (date,
 * week, day of the year, next event) like an event poster's fact sheet.
 */
AbstractBackgroundWidget {
    readonly property var nayoriDateBannerWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "calendar_date_banner"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom"
                    || root.lockBehavior === "center"
                    || root.lockBehavior === "lockOnly"
                    || (nayoriDateBannerWidget.config.options.lock.centerWidget === "calendar_date_banner")

    opacity: {
        if (root.lockBehavior === "lockOnly")
            return nayoriDateBannerWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriDateBannerWidget.globalStates.screenLocked && !visibleWhenLocked)
            return 0;
        return 1;
    }

    readonly property var options: nayoriDateBannerWidget.config.options?.background?.widgets?.calendar_date_banner ?? ({})
    readonly property real contentScale: (root.options?.widgetSize ?? 100) / 100.0
    readonly property bool italicHeadline: root.options?.italicHeadline ?? true
    readonly property bool showNextEvent: root.options?.showNextEvent ?? true

    // -- Geometry (design units) --
    readonly property real designWidth: 492
    readonly property real designHeight: 240
    readonly property real padding: 20
    readonly property real headlineMaxSize: 150
    readonly property real factGap: 12

    implicitWidth: root.designWidth * root.contentScale
    implicitHeight: root.designHeight * root.contentScale

    CalendarWidgetData {
        id: cal
    }

    readonly property var facts: {
        const today = cal.today;
        const list = [
            { label: nayoriDateBannerWidget.translation.tr("Date"), value: cal.locale.toString(today, "dd MMM yyyy") },
            { label: nayoriDateBannerWidget.translation.tr("Week"), value: String(cal.weekNumber(today)) },
            { label: nayoriDateBannerWidget.translation.tr("Day"), value: nayoriDateBannerWidget.translation.tr("%1 of %2").arg(cal.dayOfYear(today)).arg(cal.daysInYear(today)) }
        ];
        if (root.showNextEvent) {
            const next = cal.nextEvent;
            list.push({
                label: nayoriDateBannerWidget.translation.tr("Next"),
                value: next ? `${next.content} · ${cal.eventTime(next)}` : nayoriDateBannerWidget.translation.tr("Free week")
            });
        } else {
            const yearDone = Math.round(cal.dayOfYear(today) / cal.daysInYear(today) * 100);
            list.push({ label: nayoriDateBannerWidget.translation.tr("Year"), value: nayoriDateBannerWidget.translation.tr("%1% done").arg(yearDone) });
        }
        return list;
    }

    Item {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: root.contentScale

        StyledRectangularShadow {
            target: card
            visible: nayoriDateBannerWidget.config.options.background.widgets.enableShadows ?? true
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: nayoriDateBannerWidget.appearance.rounding.large
            color: nayoriDateBannerWidget.colors.tintBackground(nayoriDateBannerWidget.colors.cardBgColor)

            Text {
                id: headline
                // Fills what the fact sheet leaves; Fit sizes it to that box.
                x: root.padding
                anchors.top: parent.top
                anchors.topMargin: root.padding - 10
                anchors.bottom: factGrid.top
                anchors.bottomMargin: 2
                width: parent.width - root.padding * 2
                text: cal.locale.toString(cal.today, "dddd").toUpperCase()
                color: nayoriDateBannerWidget.colors.accentColor
                font.family: nayoriDateBannerWidget.appearance.font.family.main
                font.pixelSize: Math.round(root.headlineMaxSize)
                font.variableAxes: root.italicHeadline
                    ? ({ "wght": 900, "wdth": 82, "slnt": -10, "ROND": 0, "opsz": 144 })
                    : ({ "wght": 900, "wdth": 82, "ROND": 100, "opsz": 144 })
                fontSizeMode: Text.Fit
                minimumPixelSize: 40
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            Grid {
                id: factGrid
                x: root.padding
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.padding - 2
                width: parent.width - root.padding * 2
                columns: 2
                columnSpacing: root.factGap * 2
                rowSpacing: root.factGap

                Repeater {
                    model: root.facts

                    delegate: Column {
                        required property var modelData
                        width: (factGrid.width - factGrid.columnSpacing) / 2
                        spacing: 1

                        StyledText {
                            width: parent.width
                            text: modelData.label
                            color: nayoriDateBannerWidget.colors.subtextColorOnBg
                            font.family: nayoriDateBannerWidget.appearance.font.family.monospace
                            font.pixelSize: Math.round(nayoriDateBannerWidget.appearance.font.pixelSize.smaller)
                            elide: Text.ElideRight
                        }
                        StyledText {
                            width: parent.width
                            text: modelData.value
                            color: nayoriDateBannerWidget.colors.textColorOnBg
                            font.family: nayoriDateBannerWidget.appearance.font.family.monospace
                            font.pixelSize: Math.round(nayoriDateBannerWidget.appearance.font.pixelSize.normal)
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
