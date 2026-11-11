import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick



Item {
    readonly property var nayoriClockFaceMaterial: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 900
    property real maxHeight: 900
    property real minAspect: 0.7
    property real maxAspect: 1.3
    property bool isRound: false

    property var currentTime: nayoriClockFaceMaterial.dateTime.now

    readonly property string hoursStr: {
        if (typeof DateTime !== "undefined" && nayoriClockFaceMaterial.dateTime.hour !== undefined && String(nayoriClockFaceMaterial.dateTime.hour) !== "") {
            return String(nayoriClockFaceMaterial.dateTime.hour).padStart(2, "0");
        }
        return String(currentTime.getHours()).padStart(2, "0");
    }

    readonly property string minutesStr: {
        if (typeof DateTime !== "undefined" && nayoriClockFaceMaterial.dateTime.minute !== undefined && String(nayoriClockFaceMaterial.dateTime.minute) !== "") {
            return String(nayoriClockFaceMaterial.dateTime.minute).padStart(2, "0");
        }
        return String(currentTime.getMinutes()).padStart(2, "0");
    }

    MaterialDigitGrid {
        anchors.centerIn: parent
        hours: root.hoursStr
        minutes: root.minutesStr
        fitWidth: root.width * 0.94
        fitHeight: root.height * 0.94
        colorA: nayoriClockFaceMaterial.pythonTheme.onSurface ?? nayoriClockFaceMaterial.pythonTheme.text
        colorB: nayoriClockFaceMaterial.pythonTheme.primary ?? nayoriClockFaceMaterial.pythonTheme.mauve
    }
}
