import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects







AbstractBackgroundWidget {
    readonly property var nayoriCalendarUpcoming3DaysWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "calendar_upcoming_3days"

    implicitWidth: 240
    implicitHeight: 240

    readonly property color cardBgColor: nayoriCalendarUpcoming3DaysWidget.colors.cardBgColor
    readonly property color textColorOnBg: nayoriCalendarUpcoming3DaysWidget.colors.textColorOnBg

    readonly property color createButtonBgColor: nayoriCalendarUpcoming3DaysWidget.colors.innerShapeColor


    // Stable date calculation without re-triggering model on clock seconds or events updates
    readonly property date todayDate: nayoriCalendarUpcoming3DaysWidget.dateTime.clock.date
    readonly property int todayDayNum: todayDate ? todayDate.getDate() : 0
    readonly property int eventsCount: nayoriCalendarUpcoming3DaysWidget.calendarService.events ? nayoriCalendarUpcoming3DaysWidget.calendarService.events.length : 0

    // Statically helper function for date filtering
    function getEventsForDate(targetDate) {
        if (!nayoriCalendarUpcoming3DaysWidget.calendarService.khalAvailable || !nayoriCalendarUpcoming3DaysWidget.calendarService.events) return [];
        // Nayori events can span midnight; keep the original face and group by overlap.
        let list = nayoriCalendarUpcoming3DaysWidget.calendarService.eventsForDay(targetDate).slice();
        list.sort((a, b) => a.startDate - b.startDate);
        const limit = nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.calendar_upcoming_3days.maxEventsPerDay ?? 0;
        return limit > 0 ? list.slice(0, limit) : list;
    }

    // Fixed 3-day data model structure
    readonly property var next3DaysGrouped: {
        let trackedDay = root.todayDayNum;
        let trackedEvents = root.eventsCount;
        let now = root.todayDate;
        if (!now) now = new Date();

        let daysList = [];
        const daysShown = Math.max(1, Math.min(3,
            nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.calendar_upcoming_3days.daysShown ?? 3));
        for (let d = 0; d < daysShown; d++) {
            let dayDate = new Date(now);
            dayDate.setDate(now.getDate() + d);

            daysList.push({
                "date": dayDate,
                "isToday": d === 0,
                "dateString": Qt.locale().toString(dayDate, "ddd, MMM d"),
                "events": root.getEventsForDate(dayDate)
            });
        }
        return daysList;
    }

    StyledRectangularShadow {
        id: shadowEffect
        target: bgRect
        visible: nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: nayoriCalendarUpcoming3DaysWidget.colors.tintBackground(root.cardBgColor)
        radius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.windowRounding

        layer.enabled: nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.enableInnerShadow ?? true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bgRect.width
                height: bgRect.height
                radius: bgRect.radius
                antialiasing: true
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 16
            anchors.bottomMargin: 0

            ListView {
                id: daysListView
                anchors.fill: parent
                anchors.bottomMargin: 0
                spacing: 12
                clip: true

                model: root.next3DaysGrouped

                delegate: ColumnLayout {
                    id: dayColumn
                    required property int index
                    required property var modelData
                    readonly property bool isTodayItem: modelData.isToday
                    width: daysListView.width
                    spacing: 6

                    // Day Header Row: "Sat, Jul 27" + (+) button ONLY for today
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: modelData.dateString
                            font {
                                pixelSize: 18
                                weight: Font.Bold
                                family: "Google Sans Flex"
                            }
                            color: root.expressive ? (isTodayItem ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary : nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary) : root.textColorOnBg
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Circular Create Event Button (+) on today's section
                        RippleButton {
                            id: createBtn
                            visible: isTodayItem
                                && (nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.calendar_upcoming_3days.showAddButton ?? true)
                            implicitWidth: 40
                            implicitHeight: 28
                            topLeftRadius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.full
                            topRightRadius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.full
                            bottomLeftRadius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.full
                            bottomRightRadius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.full

                            colBackground: root.expressive ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colPrimary : root.createButtonBgColor
                            colBackgroundHover: nayoriCalendarUpcoming3DaysWidget.colors.colors.colLayer1Hover
                            colRipple: nayoriCalendarUpcoming3DaysWidget.colors.colors.colLayer1Active

                            StyledText {
                                anchors.centerIn: parent
                                text: "+"
                                font {
                                    pixelSize: 20
                                    weight: Font.Bold
                                    family: "Google Sans Flex"
                                }
                                color: root.expressive ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary : root.textColorOnBg
                            }

                            onClicked: nayoriCalendarUpcoming3DaysWidget.spawn.runApp(["xdg-open", "https://calendar.google.com/calendar/u/0/r"], { label: "calendar" })
                        }
                    }

                    // Events List under this Day
                    Repeater {
                        model: modelData.events
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: eventCol.implicitHeight + 20
                            radius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.normal

                            color: root.expressive 
                                ? (dayColumn.isTodayItem ? nayoriCalendarUpcoming3DaysWidget.colors.accentColor : nayoriCalendarUpcoming3DaysWidget.colors.innerShapeColor)
                                : nayoriCalendarUpcoming3DaysWidget.colors.innerShapeColor

                            ColumnLayout {
                                id: eventCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 2

                                StyledText {
                                    text: modelData.content || modelData.summary || nayoriCalendarUpcoming3DaysWidget.translation.tr("Event")
                                    font {
                                        pixelSize: 16
                                        weight: Font.Normal
                                        family: "Google Sans Flex"
                                    }
                                    color: root.expressive
                                        ? (dayColumn.isTodayItem ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary : nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary)
                                        : nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: {
                                        if (modelData.allDay) return nayoriCalendarUpcoming3DaysWidget.translation.tr("All Day");
                                        const format = nayoriCalendarUpcoming3DaysWidget.config.options.time.format || "hh:mm";
                                        let st = Qt.formatDateTime(new Date(modelData.startDate), format);
                                        let et = Qt.formatDateTime(new Date(modelData.endDate), format);
                                        return st + " - " + et;
                                    }
                                    font {
                                        pixelSize: 13
                                        weight: Font.ExtraBold
                                        bold: true
                                        family: "Google Sans Flex"
                                    }
                                    color: root.expressive
                                        ? (dayColumn.isTodayItem 
                                            ? Qt.rgba(nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary.r, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary.g, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary.b, 0.8)
                                            : Qt.rgba(nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary.r, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary.g, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary.b, 0.8))
                                        : Qt.rgba(nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.r, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.g, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.b, 0.75)
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // Placeholder if day has no events
                    Rectangle {
                        visible: modelData.events.length === 0
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: nayoriCalendarUpcoming3DaysWidget.appearance.rounding.normal
                        color: root.expressive 
                            ? (dayColumn.isTodayItem ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colPrimary : nayoriCalendarUpcoming3DaysWidget.colors.colors.colSecondary)
                            : nayoriCalendarUpcoming3DaysWidget.colors.colors.colSurfaceContainerLow

                        StyledText {
                            anchors.centerIn: parent
                            text: nayoriCalendarUpcoming3DaysWidget.translation.tr("No Events")
                            font {
                                pixelSize: 13
                                weight: Font.Medium
                                family: nayoriCalendarUpcoming3DaysWidget.appearance.font.family.main
                            }
                            color: root.expressive
                                ? (dayColumn.isTodayItem ? nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnPrimary : nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSecondary)
                                : Qt.rgba(nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.r, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.g, nayoriCalendarUpcoming3DaysWidget.colors.colors.colOnSurfaceVariant.b, 0.75)
                        }
                    }
                }

                TouchpadScrollHandler {
                    flickable: daysListView
                }
            }
        }

        Canvas {
            id: shadowMaskCanvas
            x: -80
            y: -80
            width: bgRect.width + 160
            height: bgRect.height + 160
            visible: false

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "black";
                ctx.beginPath();
                ctx.rect(0, 0, width, height);

                var rx = 80;
                var ry = 80;
                var rw = bgRect.width;
                var rh = bgRect.height;
                var r = bgRect.radius;

                ctx.moveTo(rx + r, ry);
                ctx.arcTo(rx, ry, rx, ry + r, r);
                ctx.lineTo(rx, ry + rh - r);
                ctx.arcTo(rx, ry + rh, rx + r, ry + rh, r);
                ctx.lineTo(rx + rw - r, ry + rh);
                ctx.arcTo(rx + rw, ry + rh, rx + rw, ry + rh - r, r);
                ctx.lineTo(rx + rw, ry + r);
                ctx.arcTo(rx + rw, ry, rx + rw - r, ry, r);
                ctx.lineTo(rx + r, ry);

                ctx.closePath();
                ctx.fill("evenodd");
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        DropShadow {
            id: innerShadow
            x: -80
            y: -80
            width: shadowMaskCanvas.width
            height: shadowMaskCanvas.height
            source: shadowMaskCanvas
            radius: 24
            samples: 49
            color: Qt.rgba(0, 0, 0, 0.35)
            horizontalOffset: 0
            verticalOffset: 0
            visible: nayoriCalendarUpcoming3DaysWidget.config.options.background.widgets.enableInnerShadow ?? true
        }
    }
}
