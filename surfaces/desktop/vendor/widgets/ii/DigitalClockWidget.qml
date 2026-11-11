import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts






AbstractBackgroundWidget {
    readonly property var nayoriDigitalClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_digital"

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    property bool wallpaperSafetyTriggered: false

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom" || root.lockBehavior === "center" || root.lockBehavior === "lockOnly"
    opacity: {
        if (root.lockBehavior === "lockOnly") return nayoriDigitalClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriDigitalClockWidget.globalStates.screenLocked && !visibleWhenLocked) return 0;
        return 1;
    }

    needsColText: true

    property var textHorizontalAlignment: {
        if (root.forceCenter || !nayoriDigitalClockWidget.config.options.background.widgets.clock_digital.adaptiveAlignment || nayoriDigitalClockWidget.config.options.background.widgets.clock_digital.vertical)
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    StyledDropShadow {
        target: contentColumn
        visible: nayoriDigitalClockWidget.config.options.background.widgets.enableShadows ?? false
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 10

        DigitalClock {
            textHorizontalAlignment: root.textHorizontalAlignment
        }
    }
}
