import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.



import QtQuick
import QtQuick.Layouts

StyledText {
    readonly property var nayoriClockText: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    Layout.fillWidth: true
    font {
        family: nayoriClockText.appearance.font.family.expressive
        pixelSize: 20
        weight: 350
        // Set empty to prevent conflicts, not meaningless
        styleName: ""
        variableAxes: ({})
        // Tabular digits: a narrow "1" would otherwise shrink its line
        features: ({ "tnum": 1 })
    }
    // Distance-field glyphs turn polygonal at display sizes; curves stay smooth
    renderType: Text.CurveRendering
    style: Text.Raised
    styleColor: nayoriClockText.colors.colors.colShadow
    animateChange: nayoriClockText.config.options.background.widgets.clock_digital.animateChange
}
