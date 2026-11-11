import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts







AbstractBackgroundWidget {
    readonly property var nayoriCookieClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_cookie"

    implicitWidth: 240
    implicitHeight: 240

    property bool wallpaperSafetyTriggered: false

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom" || root.lockBehavior === "center" || root.lockBehavior === "lockOnly" || (nayoriCookieClockWidget.config.options.lock.centerWidget === "clock_cookie")
    opacity: {
        if (root.lockBehavior === "lockOnly") return nayoriCookieClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriCookieClockWidget.globalStates.screenLocked && !visibleWhenLocked) return 0;
        return 1;
    }

    needsColText: false

    Column {
        anchors.centerIn: parent
        spacing: 10

        CookieClock {
            live: root.live
        }

        FadeLoader {
            anchors.horizontalCenter: parent.horizontalCenter
            shown: nayoriCookieClockWidget.config.options.background.widgets.clock_cookie.quoteEnable && nayoriCookieClockWidget.config.options.background.widgets.clock_cookie.quoteText !== ""
            sourceComponent: CookieQuote {}
        }

        // Status row
        Item {
            id: statusText
            implicitHeight: statusTextBg.implicitHeight
            implicitWidth: statusTextBg.implicitWidth
            anchors.horizontalCenter: parent.horizontalCenter
            StyledRectangularShadow {
                target: statusTextBg
                visible: statusTextBg.visible && (nayoriCookieClockWidget.config.options.background.widgets.enableShadows ?? true)
                opacity: statusTextBg.opacity
            }
            Rectangle {
                id: statusTextBg
                anchors.centerIn: parent
                clip: true
                opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
                visible: opacity > 0
                implicitHeight: statusTextRow.implicitHeight + 5 * 2
                implicitWidth: statusTextRow.implicitWidth + 5 * 2
                radius: nayoriCookieClockWidget.appearance.rounding.small
                color: nayoriCookieClockWidget.colorUtils.transparentize(nayoriCookieClockWidget.colors.colors.colSecondaryContainer, 0)

                Behavior on implicitWidth {
                    NumberAnimation { duration: nayoriCookieClockWidget.motionDuration; easing.type: Easing.OutCubic }
                }
                Behavior on implicitHeight {
                    NumberAnimation { duration: nayoriCookieClockWidget.motionDuration; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: nayoriCookieClockWidget.motionDuration; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: statusTextRow
                    anchors.centerIn: parent
                    spacing: 14
                    ClockStatusText {
                        id: safetyStatusText
                        shown: root.wallpaperSafetyTriggered
                        statusIcon: "hide_image"
                        statusText: nayoriCookieClockWidget.translation.tr("Wallpaper safety enforced")
                    }
                    ClockStatusText {
                        id: lockStatusText
                        shown: nayoriCookieClockWidget.globalStates.screenLocked && nayoriCookieClockWidget.config.options.lock.showLockedText
                        statusIcon: "lock"
                        statusText: nayoriCookieClockWidget.translation.tr("Locked")
                    }
                }
            }
        }
    }

    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        property color textColor: nayoriCookieClockWidget.colors.colors.colOnSecondaryContainer
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: nayoriCookieClockWidget.motionDuration; easing.type: Easing.OutCubic }
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: nayoriCookieClockWidget.appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: Text.Raised
            styleColor: nayoriCookieClockWidget.colors.colors.colShadow
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: nayoriCookieClockWidget.appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: Text.Raised
            styleColor: nayoriCookieClockWidget.colors.colors.colShadow
        }
    }
}
