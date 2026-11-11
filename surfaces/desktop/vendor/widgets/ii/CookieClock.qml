import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io








Item {
    readonly property var nayoriCookieClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property real implicitSize: 240

    property color colShadow: nayoriCookieClock.colors.colors.colShadow
    property color colBackground: nayoriCookieClock.colors.cardBgColor
    property color colOnBackground: nayoriCookieClock.colors.textColorOnBg
    property color colBackgroundInfo: nayoriCookieClock.colors.innerShapeColor
    property color colHourHand: nayoriCookieClock.colors.accentColor
    property color colMinuteHand: nayoriCookieClock.colors.subtextColorOnBg
    property color colSecondHand: nayoriCookieClock.colors.surfaceVariantColor
    property color colHourMarks: nayoriCookieClock.colors.subtextColorOnBg
    property color colMinuteMarks: nayoriCookieClock.colors.subtextColorOnBg
    property color colTimeColumn: Qt.rgba(nayoriCookieClock.colors.textColorOnPillTrack.r, nayoriCookieClock.colors.textColorOnPillTrack.g, nayoriCookieClock.colors.textColorOnPillTrack.b, 0.5)
    property color colCenterDot: nayoriCookieClock.colors.pillFillColor

    readonly property var clockNumbers: nayoriCookieClock.dateTime.time.split(/[: ]/)
    readonly property int clockHour: parseInt(clockNumbers[0]) % 12
    readonly property int clockMinute: nayoriCookieClock.dateTime.clock.minutes
    property int clockSecond: nayoriCookieClock.dateTime.clock.seconds

    readonly property bool secondHandVisible: nayoriCookieClock.config.options.background.widgets.clock_cookie.secondHandStyle !== "hide"

    /** Set by the widget hosting this dial: false while the desktop is covered. */
    property bool live: true

    Timer {
        running: root.secondHandVisible && !nayoriCookieClock.config.options.time.secondPrecision && root.live
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.clockSecond = new Date().getSeconds()
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    function applyStyle(sides, dialStyle, hourHandStyle, minuteHandStyle, secondHandStyle, dateStyle) {
        nayoriCookieClock.config.options.background.widgets.clock_cookie.sides = sides
        nayoriCookieClock.config.options.background.widgets.clock_cookie.dialNumberStyle = dialStyle
        nayoriCookieClock.config.options.background.widgets.clock_cookie.hourHandStyle = hourHandStyle
        nayoriCookieClock.config.options.background.widgets.clock_cookie.minuteHandStyle = minuteHandStyle
        nayoriCookieClock.config.options.background.widgets.clock_cookie.secondHandStyle = secondHandStyle
        nayoriCookieClock.config.options.background.widgets.clock_cookie.dateStyle = dateStyle
    }

    function setClockPreset(category) {
        if (!nayoriCookieClock.config.options.background.widgets.clock_cookie.aiStyling) return;
        if (category === "") return;
        print("[Cookie clock] Setting clock preset for category: " + category)
        // "abstract", "anime", "city", "minimalist", "landscape", "plants", "person", "space"
        if (category == "abstract") {
            applyStyle(9, "none", "fill", "medium", "dot", "bubble")
        } else if (category == "anime") {
            applyStyle(7, "none", "fill", "bold", "dot", "bubble")
        } else if (category == "city" || category == "space") {
            applyStyle(23, "full", "hollow", "thin", "classic", "bubble")
        } else if (category == "minimalist") {
            applyStyle(6, "none", "fill", "bold", "dot", "hide")
        } else if (category == "landscape") {
            applyStyle(14, "full", "hollow", "medium", "classic", "bubble")
        } else if (category == "plants") {
            applyStyle(9, "dots", "fill", "bold", "dot", "border")
        } else if (category == "person") {
            applyStyle(14, "full", "classic", "classic", "classic", "rect")
        }
    }

    FileView {
        id: categoryFileView
        path: nayoriCookieClock.config.ready ? nayoriCookieClock.directories.generatedWallpaperCategoryPath : ""
        printErrors: false // only written once a wallpaper has been categorised
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            root.setClockPreset(categoryFileView.text().trim())
        }
    }

    readonly property bool enableShadows: nayoriCookieClock.config.options.background.widgets.enableShadows ?? true
    property string backgroundStyle: nayoriCookieClock.config.options.background.widgets.clock_cookie.backgroundStyle

    Item {
        id: cookieShapeContainer
        anchors.fill: parent

        RotationAnimation on rotation {
            running: nayoriCookieClock.config.options.background.widgets.clock_cookie.constantlyRotate && root.live
            duration: (nayoriCookieClock && nayoriCookieClock.reducedMotion ? 0 : 30000)
            easing.type: Easing.Linear
            loops: Animation.Infinite
            from: 360
            to: 0
        }

        StyledDropShadow {
            target: backgroundStyle === "sine" ? sineCookieLoader : backgroundStyle === "shape" ? materialShapeCookieLoader : roundedPolygonCookieLoader
            visible: root.enableShadows
        }
        Loader {
            id: sineCookieLoader
            z: 0
            visible: !root.enableShadows // Show target directly when shadows are disabled
            active: backgroundStyle === "sine"
            sourceComponent: SineCookie {
                implicitSize: root.implicitSize
                sides: nayoriCookieClock.config.options.background.widgets.clock_cookie.sides
                color: nayoriCookieClock.colors.tintBackground(root.colBackground)
            }
        }
        Loader {
            id: roundedPolygonCookieLoader
            z: 0
            visible: !root.enableShadows // Show target directly when shadows are disabled
            active: backgroundStyle === "cookie"
            sourceComponent: MaterialCookie {
                implicitSize: root.implicitSize
                sides: nayoriCookieClock.config.options.background.widgets.clock_cookie.sides
                color: nayoriCookieClock.colors.tintBackground(root.colBackground)
            }
        }
        Loader {
            id: materialShapeCookieLoader
            z: 0
            visible: !root.enableShadows // Show target directly when shadows are disabled
            active: backgroundStyle === "shape"
            sourceComponent: MaterialShape {
                implicitSize: root.implicitSize
                color: nayoriCookieClock.colors.tintBackground(root.colBackground)
                shapeString: nayoriCookieClock.config.options.background.widgets.clock_cookie.backgroundShape
            }
        }
    }

    // Hour/minutes numbers/dots/lines
    MinuteMarks {
        anchors.fill: parent
        color: root.colMinuteMarks
    }

    // Stupid extra hour marks in the middle
    FadeLoader {
        id: hourMarksLoader
        anchors.centerIn: parent
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.hourMarks
        sourceComponent: HourMarks {
            implicitSize: 135 * (1.75 - 0.75 * hourMarksLoader.opacity)
            color: root.colHourMarks
            colOnBackground: nayoriCookieClock.colorUtils.mix(root.colBackgroundInfo, root.colOnBackground, 0.5)
        }
    }

    // Number column in the middle
    FadeLoader {
        id: timeColumnLoader
        anchors.centerIn: parent
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.timeIndicators
        scale: 1.4 - 0.4 * timeColumnLoader.shown
        Behavior on scale {
            NumberAnimation { duration: nayoriCookieClock.motionDuration; easing.type: Easing.OutCubic }
        }

        sourceComponent: TimeColumn {
            color: root.colTimeColumn
        }
    }

    // Minute hand
    FadeLoader {
        anchors.fill: parent
        z: 1
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.minuteHandStyle !== "hide"
        sourceComponent: MinuteHand {
            anchors.fill: parent
            clockMinute: root.clockMinute
            style: nayoriCookieClock.config.options.background.widgets.clock_cookie.minuteHandStyle
            color: root.colMinuteHand
        }
    }

    // Hour hand
    FadeLoader {
        anchors.fill: parent
        z: (item && item.style === "hollow") ? 0 : 2
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.hourHandStyle !== "hide"
        sourceComponent: HourHand {
            clockHour: root.clockHour
            clockMinute: root.clockMinute
            style: nayoriCookieClock.config.options.background.widgets.clock_cookie.hourHandStyle
            color: root.colHourHand
        }
    }

    // Second hand
    FadeLoader {
        id: secondHandLoader
        z: (nayoriCookieClock.config.options.background.widgets.clock_cookie.secondHandStyle === "line") ? 2 : 3
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.secondHandStyle !== "hide"
        anchors.fill: parent
        sourceComponent: SecondHand {
            id: secondHand
            clockSecond: root.clockSecond
            style: nayoriCookieClock.config.options.background.widgets.clock_cookie.secondHandStyle
            color: root.colSecondHand
        }
    }

    // Center dot
    FadeLoader {
        z: 4
        anchors.centerIn: parent
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.minuteHandStyle !== "bold"
        sourceComponent: Rectangle {
            color: nayoriCookieClock.config.options.background.widgets.clock_cookie.minuteHandStyle === "medium" ? root.colBackground : root.colCenterDot
            implicitWidth: 6
            implicitHeight: implicitWidth
            radius: width / 2
        }
    }

    // Date
    FadeLoader {
        anchors.fill: parent
        shown: nayoriCookieClock.config.options.background.widgets.clock_cookie.dateStyle !== "hide"

        sourceComponent: DateIndicator {
            color: root.colBackgroundInfo
            style: nayoriCookieClock.config.options.background.widgets.clock_cookie.dateStyle
        }
    }
}
