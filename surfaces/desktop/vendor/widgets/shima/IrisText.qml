import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts



StyledText {
    readonly property var nayoriIrisText: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    enum Role { Body, Meta, Eyebrow, Title, Display, Metric }
    property int role: IrisText.Body

    color: role === IrisText.Meta || role === IrisText.Eyebrow ? nayoriIrisText.irisStyle.subtext : nayoriIrisText.irisStyle.text
    defaultFont: (role === IrisText.Title || role === IrisText.Display)
        ? nayoriIrisText.irisStyle.fontTitle
        : role === IrisText.Metric ? nayoriIrisText.irisStyle.fontNumbers
        : nayoriIrisText.irisStyle.fontMain
    font.family: defaultFont
    font.pixelSize: role === IrisText.Meta ? nayoriIrisText.irisStyle.typeMeta
        : role === IrisText.Eyebrow ? nayoriIrisText.irisStyle.typeFootnote
        : role === IrisText.Title ? nayoriIrisText.irisStyle.typeTitle
        : role === IrisText.Display ? nayoriIrisText.irisStyle.typeDisplay
        : role === IrisText.Metric ? nayoriIrisText.irisStyle.typeTitleLarge : nayoriIrisText.irisStyle.typeBody
    font.weight: nayoriIrisText.irisStyle.weight(role === IrisText.Meta ? Font.Normal
        : role === IrisText.Eyebrow ? Font.DemiBold
        : role === IrisText.Title ? Font.DemiBold
        : role === IrisText.Display || role === IrisText.Metric ? Font.Bold : Font.Medium)
    font.letterSpacing: role === IrisText.Display ? nayoriIrisText.irisStyle.tracking(nayoriIrisText.irisStyle.typeDisplay)
        : role === IrisText.Metric ? nayoriIrisText.irisStyle.tracking(nayoriIrisText.irisStyle.typeTitleLarge) : 0
    font.variableAxes: ({})
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
