import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts




AbstractBackgroundWidget {
    readonly property var nayoriWordClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_word"
    readonly property var cfg: nayoriWordClockWidget.config.options.background.widgets.clock_word
    implicitWidth: cfg.size ?? 240
    implicitHeight: cfg.size ?? 240

    readonly property int hourNumber: {
        const h = nayoriWordClockWidget.dateTime.clock.hours % 12;
        return h === 0 ? 12 : h;
    }
    readonly property string hourWord: numberWord(hourNumber)
    readonly property int minuteNumber: nayoriWordClockWidget.dateTime.clock.minutes
    readonly property string minuteTensWord: minuteNumber >= 10 && minuteNumber <= 19
                                             ? numberWord(minuteNumber)
                                             : numberWord(Math.floor(minuteNumber / 10) * 10)
    readonly property string minuteOnesWord: (minuteNumber >= 10 && minuteNumber <= 19) || minuteNumber % 10 === 0
                                             ? ""
                                             : numberWord(minuteNumber % 10)

    function numberWord(value) {
        const words = [nayoriWordClockWidget.translation.tr("Zero"), nayoriWordClockWidget.translation.tr("One"), nayoriWordClockWidget.translation.tr("Two"), nayoriWordClockWidget.translation.tr("Three"), nayoriWordClockWidget.translation.tr("Four"), nayoriWordClockWidget.translation.tr("Five"), nayoriWordClockWidget.translation.tr("Six"), nayoriWordClockWidget.translation.tr("Seven"), nayoriWordClockWidget.translation.tr("Eight"), nayoriWordClockWidget.translation.tr("Nine"), nayoriWordClockWidget.translation.tr("Ten"), nayoriWordClockWidget.translation.tr("Eleven"), nayoriWordClockWidget.translation.tr("Twelve"), nayoriWordClockWidget.translation.tr("Thirteen"), nayoriWordClockWidget.translation.tr("Fourteen"), nayoriWordClockWidget.translation.tr("Fifteen"), nayoriWordClockWidget.translation.tr("Sixteen"), nayoriWordClockWidget.translation.tr("Seventeen"), nayoriWordClockWidget.translation.tr("Eighteen"), nayoriWordClockWidget.translation.tr("Nineteen"), nayoriWordClockWidget.translation.tr("Twenty"), nayoriWordClockWidget.translation.tr("Thirty"), nayoriWordClockWidget.translation.tr("Forty"), nayoriWordClockWidget.translation.tr("Fifty")];
        if (value <= 19) return words[value];
        return words[18 + Math.floor(value / 10)];
    }

    StyledDropShadow {
        target: backgroundShape
        visible: backgroundShape.visible && (nayoriWordClockWidget.config.options.background.widgets.enableShadows ?? false)
    }

    MaterialShape {
        id: backgroundShape
        anchors.fill: parent
        visible: (root.cfg.backgroundStyle ?? "shape") === "shape"
        color: nayoriWordClockWidget.colors.tintBackground(nayoriWordClockWidget.colors.cardBgColor)
        shapeString: root.cfg.backgroundShape ?? "Circle"
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.60
        spacing: -root.height * 0.025

        StyledText {
            Layout.fillWidth: true
            Layout.preferredHeight: font.pixelSize * 1.08
            text: root.hourWord
            color: nayoriWordClockWidget.colors.accentColor
            font.pixelSize: Math.round(Math.min(root.height * 0.16, root.width * 1.05 / Math.max(1, text.length)))
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.preferredHeight: font.pixelSize * 1.08
            text: root.minuteTensWord
            color: nayoriWordClockWidget.colors.textColorOnBg
            font.pixelSize: Math.round(Math.min(root.height * 0.16, root.width * 1.05 / Math.max(1, text.length)))
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? font.pixelSize * 1.08 : 0
            text: root.minuteOnesWord
            color: nayoriWordClockWidget.colors.textColorOnBg
            font.pixelSize: Math.round(Math.min(root.height * 0.16, root.width * 1.05 / Math.max(1, text.length)))
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            visible: text !== ""
        }
    }
}
