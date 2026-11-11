import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects





AbstractBackgroundWidget {
    readonly property var nayoriQuoteWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "quote"

    implicitWidth: 240
    implicitHeight: 240

    readonly property color cardBgColor: nayoriQuoteWidget.colors.cardBgColor
    readonly property color textColorOnBg: nayoriQuoteWidget.colors.textColorOnBg
    readonly property color iconColor: nayoriQuoteWidget.colors.subtextColorOnBg

    StyledRectangularShadow {
        id: bgShadow
        target: bgRect
        visible: nayoriQuoteWidget.config.options.background.widgets.enableShadows ?? false
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: nayoriQuoteWidget.colors.tintBackground(root.cardBgColor)
        radius: nayoriQuoteWidget.appearance.rounding.windowRounding

        layer.enabled: nayoriQuoteWidget.config.options.background.widgets.enableInnerShadow ?? false
        layer.effect: InnerShadow {
            color: Qt.rgba(0, 0, 0, 0.15)
            radius: 8.0
            samples: 16
            horizontalOffset: 0
            verticalOffset: 1
            spread: 0.0
        }

        // Top-left: opening quote (mirrored + upside-down)
        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 12
            width: 56
            height: 56
            scale: -1

            MaterialSymbol {
                anchors.fill: parent
                text: "format_quote"
                iconSize: 56
                fill: 1
                color: root.iconColor
            }
        }

        // Center: quote text
        StyledText {
            id: quoteText
            anchors.centerIn: parent
            width: parent.width - 64
            height: parent.height - 96
            text: nayoriQuoteWidget.config.options.background.widgets.quote.quoteText || nayoriQuoteWidget.translation.tr("Add your favorite quote in settings.")
            font.pixelSize: Math.round(nayoriQuoteWidget.config.options.background.widgets.quote.fontSize || nayoriQuoteWidget.appearance.font.pixelSize.normal)
            font.italic: true
            font.variableAxes: ({ "wght": 500, "wdth": 125 })
            color: root.textColorOnBg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 6
            lineHeight: 1.3
        }

        // Bottom-right: closing quote (normal orientation)
        MaterialSymbol {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 12
            iconSize: 56
            text: "format_quote"
            fill: 1
            color: root.iconColor
        }
    }
}
