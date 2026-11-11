import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick



/**
 * Material color scheme adapted to a given color. It's incomplete but enough for what we need...
 */
Item {
    readonly property var nayoriAdaptedMaterialScheme: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    required property color color
    readonly property bool colorIsDark: color.hslLightness < 0.5

    property color colLayer0: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colLayer0, root.color, (colorIsDark && nayoriAdaptedMaterialScheme.appearance.m3colors.darkmode) ? 0.6 : 0.5)
    property color colLayer1: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colLayer1, root.color, 0.5)
    property color colOnLayer0: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colOnLayer0, root.color, 0.5)
    property color colOnLayer1: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colOnLayer1, root.color, 0.5)
    property color colSubtext: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colOnLayer1, root.color, 0.5)
    property color colPrimary: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.colorUtils.adaptToAccent(nayoriAdaptedMaterialScheme.appearance.colors.colPrimary, root.color), root.color, 0.5)
    property color colPrimaryHover: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.colorUtils.adaptToAccent(nayoriAdaptedMaterialScheme.appearance.colors.colPrimaryHover, root.color), root.color, 0.3)
    property color colPrimaryActive: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.colorUtils.adaptToAccent(nayoriAdaptedMaterialScheme.appearance.colors.colPrimaryActive, root.color), root.color, 0.3)
    property color colSecondary: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.colorUtils.adaptToAccent(nayoriAdaptedMaterialScheme.appearance.colors.colSecondary, root.color), root.color, 0.5)
    property color colSecondaryContainer: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colSecondaryContainer, root.color, 0.15)
    property color colSecondaryContainerHover: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colSecondaryContainerHover, root.color, 0.3)
    property color colSecondaryContainerActive: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colSecondaryContainerActive, root.color, 0.5)
    property color colOnPrimary: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.colorUtils.adaptToAccent(nayoriAdaptedMaterialScheme.appearance.colors.colOnPrimary, root.color), root.color, 0.5)
    property color colOnSecondaryContainer: nayoriAdaptedMaterialScheme.colorUtils.mix(nayoriAdaptedMaterialScheme.appearance.colors.colOnSecondaryContainer, root.color, 0.5)
}
