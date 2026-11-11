import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts


StyledText {
    readonly property var nayoriFaceText: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    required property var face
    property real size: 13
    property int weight: Font.Medium

    color: face.ink
    font.family: face.fontMain
    font.pixelSize: face.px(size)
    font.weight: weight
    font.letterSpacing: 0
    elide: Text.ElideRight
    maximumLineCount: 1
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
