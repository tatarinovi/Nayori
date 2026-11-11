import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick





Item {
    readonly property var nayoriConcentricArc24h: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property color textColor: nayoriConcentricArc24h.colors.textColorOnBg
    property color subtextColor: nayoriConcentricArc24h.colors.subtextColorOnBg
    property color accentColor: nayoriConcentricArc24h.colors.accentColor

    property int hour: nayoriConcentricArc24h.dateTime.clock.hours
    property int minute: nayoriConcentricArc24h.dateTime.clock.minutes
    readonly property real progress: (hour * 60 + minute) / 1440.0

    anchors.fill: parent

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var cx = width / 2;
            var cy = height / 2;
            var r = width * 0.43;

            var startAngle = Math.PI * 1.15; // ~207 deg
            var endAngle = Math.PI * 1.85;   // ~333 deg

            // Track
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, endAngle);
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = nayoriConcentricArc24h.colorUtils.applyAlpha(root.subtextColor, 0.25);
            ctx.stroke();

            // Active Arc
            var currentAngle = startAngle + (endAngle - startAngle) * root.progress;
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, currentAngle);
            ctx.lineWidth = 2.5;
            ctx.strokeStyle = root.accentColor;
            ctx.stroke();
        }

        Connections {
            target: nayoriConcentricArc24h.dateTime.clock
            function onMinutesChanged() { arcCanvas.requestPaint(); }
        }
    }

    StyledText {
        text: "≈24"
        color: root.subtextColor
        font.pixelSize: Math.round(parent.width * 0.035)
        font.weight: Font.DemiBold
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.04
    }
}
