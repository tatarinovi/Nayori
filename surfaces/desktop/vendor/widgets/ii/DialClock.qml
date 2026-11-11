import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.






import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    readonly property var nayoriDialClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property real implicitSize: 240

    property color colBackground: nayoriDialClock.colors.cardBgColor
    property color colBorder: nayoriDialClock.colors.textColorOnBg
    property color colTicks: nayoriDialClock.colors.textColorOnBg
    property color colNumbers: nayoriDialClock.colors.textColorOnBg
    property color colHourHand: nayoriDialClock.colors.accentColor
    property color colMinuteHand: nayoriDialClock.colors.subtextColorOnBg

    readonly property list<string> clockNumbers: nayoriDialClock.dateTime.time.split(/[: ]/)
    readonly property int clockHour: parseInt(clockNumbers[0]) % 12
    readonly property int clockMinute: nayoriDialClock.dateTime.clock.minutes
    property int clockSecond: nayoriDialClock.dateTime.clock.seconds

    /** Set by the widget hosting this dial: false while the desktop is covered. */
    property bool live: true

    Timer {
        interval: 1000
        running: root.live
        repeat: true
        triggeredOnStart: true
        onTriggered: root.clockSecond = new Date().getSeconds()
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // ── Config-driven toggles ──
    readonly property bool showTicks: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.showTicks ?? true) : true
    readonly property bool showMinuteHand: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.showMinuteHand ?? true) : true
    readonly property bool showSecondHand: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.showSecondHand ?? false) : false
    readonly property string hourHandStyle: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.hourHandStyle ?? "fill") : "fill"
    readonly property string minuteHandStyle: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.minuteHandStyle ?? "medium") : "medium"
    readonly property string secondHandStyle: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.secondHandStyle ?? "dot") : "dot"
    readonly property bool showNumberRing: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.showNumberRing ?? false) : false

    // Outer drop shadow support
    StyledDropShadow {
        id: outerShadow
        target: dialBody
        visible: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.enableShadows ?? true) : true
    }

    // Base Dial Plate
    Rectangle {
        id: dialBody
        anchors.fill: parent
        color: nayoriDialClock.colors.tintBackground(root.colBackground)
        radius: width / 2
        clip: true

        // Inner shadow container
        Item {
            id: shadowContainer
            anchors.fill: parent
            z: 0.1
            layer.enabled: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.enableInnerShadow ?? true) : true
            layer.smooth: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: shadowContainer.width
                    height: shadowContainer.height
                    radius: dialBody.radius
                    antialiasing: true
                }
            }

            Canvas {
                id: shadowMaskCanvas
                x: -80
                y: -80
                width: shadowContainer.width + 160
                height: shadowContainer.height + 160
                visible: false

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "black";
                    ctx.beginPath();
                    ctx.rect(0, 0, width, height);
                    ctx.arc(width / 2, height / 2, shadowContainer.width / 2, 0, 2 * Math.PI);
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
                visible: nayoriDialClock.config.ready ? (nayoriDialClock.config.options.background.widgets.clock_dial.enableInnerShadow ?? true) : true
            }
        }

        // Outer Thin Ring Accent
        Rectangle {
            width: parent.width - 12
            height: parent.height - 12
            radius: width / 2
            color: "transparent"
            border.color: root.colBorder
            border.width: 2
            anchors.centerIn: parent
        }

        // Inner Thick Ring Accent
        Rectangle {
            width: parent.width - 24
            height: parent.height - 24
            radius: width / 2
            color: "transparent"
            border.color: root.colBorder
            border.width: 8
            anchors.centerIn: parent
            opacity: 0.15
        }

        // Ticks track (120 radial lines)
        Canvas {
            id: ticksCanvas
            anchors.fill: parent
            visible: root.showTicks
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = root.colTicks;
                ctx.lineWidth = 1.5;

                var cx = width / 2;
                var cy = height / 2;
                var r = cx - 12;

                for (var i = 0; i < 120; i++) {
                    var angle = (i * 3) * Math.PI / 180;
                    var tickLen = 6;
                    ctx.beginPath();
                    ctx.moveTo(cx + (r - tickLen) * Math.cos(angle), cy + (r - tickLen) * Math.sin(angle));
                    ctx.lineTo(cx + r * Math.cos(angle), cy + r * Math.sin(angle));
                    ctx.stroke();
                }
            }
        }

        // Bigger background digits (12, 3, 6, 9) — configurable via showNumberRing
        Text {
            text: "12"
            font.family: nayoriDialClock.appearance.font.family.main
            font.pixelSize: Math.round(parent.width * 0.28)
            font.weight: Font.ExtraBold
            font.bold: true
            font.variableAxes: ({ "wght": 1000 })
            color: root.colNumbers
            opacity: root.showNumberRing ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: (nayoriDialClock && nayoriDialClock.reducedMotion ? 0 : 300); easing.type: Easing.OutCubic } }
            anchors {
                top: parent.top
                topMargin: parent.height * 0.05
                horizontalCenter: parent.horizontalCenter
            }
        }

        Text {
            text: "6"
            font.family: nayoriDialClock.appearance.font.family.main
            font.pixelSize: Math.round(parent.width * 0.28)
            font.weight: Font.ExtraBold
            font.bold: true
            font.variableAxes: ({ "wght": 1000 })
            color: root.colNumbers
            opacity: root.showNumberRing ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: (nayoriDialClock && nayoriDialClock.reducedMotion ? 0 : 300); easing.type: Easing.OutCubic } }
            anchors {
                bottom: parent.bottom
                bottomMargin: parent.height * 0.05
                horizontalCenter: parent.horizontalCenter
            }
        }

        Text {
            text: "3"
            font.family: nayoriDialClock.appearance.font.family.main
            font.pixelSize: Math.round(parent.width * 0.28)
            font.weight: Font.ExtraBold
            font.bold: true
            font.variableAxes: ({ "wght": 1000 })
            color: root.colNumbers
            opacity: root.showNumberRing ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: (nayoriDialClock && nayoriDialClock.reducedMotion ? 0 : 300); easing.type: Easing.OutCubic } }
            anchors {
                right: parent.right
                rightMargin: parent.width * 0.07
                verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: "9"
            font.family: nayoriDialClock.appearance.font.family.main
            font.pixelSize: Math.round(parent.width * 0.28)
            font.weight: Font.ExtraBold
            font.bold: true
            font.variableAxes: ({ "wght": 1000 })
            color: root.colNumbers
            opacity: root.showNumberRing ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: (nayoriDialClock && nayoriDialClock.reducedMotion ? 0 : 300); easing.type: Easing.OutCubic } }
            anchors {
                left: parent.left
                leftMargin: parent.width * 0.07
                verticalCenter: parent.verticalCenter
            }
        }

        // ── Hour hand (CookieClock HourHand component) ──
        FadeLoader {
            anchors.fill: parent
            z: (item && item.style === "hollow") ? 0 : 2
            shown: root.hourHandStyle !== "hide"
            sourceComponent: HourHand {
                clockHour: root.clockHour
                clockMinute: root.clockMinute
                handLength: 72
                handWidth: 20
                style: root.hourHandStyle
                color: root.colHourHand
            }
        }

        // ── Minute hand (CookieClock MinuteHand component) ──
        FadeLoader {
            anchors.fill: parent
            z: 1
            shown: root.showMinuteHand && root.minuteHandStyle !== "hide"
            sourceComponent: MinuteHand {
                anchors.fill: parent
                clockMinute: root.clockMinute
                handLength: 95
                style: root.minuteHandStyle
                color: root.colMinuteHand
            }
        }

        // ── Second hand (CookieClock SecondHand component) — disabled by default ──
        FadeLoader {
            id: secondHandLoader
            z: (root.secondHandStyle === "line") ? 2 : 3
            shown: root.showSecondHand && root.secondHandStyle !== "hide"
            anchors.fill: parent
            sourceComponent: SecondHand {
                id: secondHand
                clockSecond: root.clockSecond
                style: root.secondHandStyle
                color: nayoriDialClock.colors.successColor
            }
        }
    }
}
