import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.



import QtQuick
import Qt5Compat.GraphicalEffects


Item {
    readonly property var nayoriCookieQuote: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property string quoteText: nayoriCookieQuote.config.options.background.widgets.concentric_clock?.quoteText || nayoriCookieQuote.config.options.background.widgets.clock_cookie?.quoteText || ""

    implicitWidth: quoteBox.implicitWidth
    implicitHeight: quoteBox.implicitHeight

    DropShadow {
        source: quoteBox
        anchors.fill: quoteBox
        horizontalOffset: 0
        verticalOffset: 2
        radius: 12
        samples: radius * 2 + 1
        color: nayoriCookieQuote.colors.colors.colShadow
        transparentBorder: true
    }

    Rectangle {
        id: quoteBox

        implicitWidth: quoteRow.implicitWidth + 8 * 2
        implicitHeight: quoteRow.implicitHeight + 4 * 2
        radius: nayoriCookieQuote.appearance.rounding.small
        color: nayoriCookieQuote.colors.tintBackground(nayoriCookieQuote.colors.innerShapeColor)

        Row {
            id: quoteRow
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                id: quoteIcon
                anchors.top: parent.top
                iconSize: nayoriCookieQuote.appearance.font.pixelSize.huge
                text: "format_quote"
                color: nayoriCookieQuote.colors.accentColor
            }
            StyledText {
                id: quoteStyledText
                horizontalAlignment: Text.AlignLeft
                text: root.quoteText
                color: nayoriCookieQuote.colors.textColorOnBg
                font {
                    family: nayoriCookieQuote.appearance.font.family.reading
                    pixelSize: nayoriCookieQuote.appearance.font.pixelSize.large
                    weight: Font.Normal
                }
            }
        }
    }
}
