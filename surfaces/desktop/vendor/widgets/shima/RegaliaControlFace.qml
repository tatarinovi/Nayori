import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick



Item {
    readonly property var nayoriRegaliaControlFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property color fillColor: nayoriRegaliaControlFace.appearance.regalia.controlPlate
    property real radius: nayoriRegaliaControlFace.appearance.regalia.controlRadius
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool focused: false

    readonly property bool _hasSurface: root.fillColor.a > 0.01
    readonly property color _fieldColor: root.pressed
        ? nayoriRegaliaControlFace.colorUtils.mix(root.fillColor, nayoriRegaliaControlFace.appearance.regalia.onColor, 0.84)
        : root.hovered ? nayoriRegaliaControlFace.colorUtils.mix(root.fillColor, nayoriRegaliaControlFace.appearance.regalia.onColor, 0.92)
        : root.fillColor

    Rectangle {
        anchors.fill: parent
        visible: root._hasSurface
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.selected
                    ? nayoriRegaliaControlFace.colorUtils.mix(nayoriRegaliaControlFace.appearance.regalia.chassisLight, nayoriRegaliaControlFace.appearance.regalia.hardwarePrimary, 0.86)
                    : nayoriRegaliaControlFace.appearance.regalia.chassisLight
            }
            GradientStop { position: 0.46; color: nayoriRegaliaControlFace.appearance.regalia.chassis1 }
            GradientStop { position: 1; color: nayoriRegaliaControlFace.appearance.regalia.chassisShade }
        }
    }

    Rectangle {
        id: keyFace
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: nayoriRegaliaControlFace.appearance.regalia.controlInset
        }
        visible: root._hasSurface || root.focused
        radius: Math.max(0, root.radius - nayoriRegaliaControlFace.appearance.regalia.controlInset)
        color: root._hasSurface ? root._fieldColor : "transparent"
        border.width: root.focused ? 1 : 0
        border.color: nayoriRegaliaControlFace.appearance.regalia.focus
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._hasSurface
                    ? nayoriRegaliaControlFace.colorUtils.mix(root._fieldColor, nayoriRegaliaControlFace.appearance.regalia.onColor,
                        root.pressed ? 0.985 : 0.955)
                    : "transparent"
            }
            GradientStop { position: 0.5; color: root._hasSurface ? root._fieldColor : "transparent" }
            GradientStop {
                position: 1
                color: root._hasSurface
                    ? nayoriRegaliaControlFace.colorUtils.mix(root._fieldColor, nayoriRegaliaControlFace.appearance.m3colors.m3shadow,
                        root.pressed ? 0.88 : 0.935)
                    : "transparent"
            }
        }

        Behavior on color {
            enabled: nayoriRegaliaControlFace.appearance.animationsEnabled
            ColorAnimation { duration: nayoriRegaliaControlFace.appearance.regalia.stateDuration; easing.type: Easing.OutCubic }
        }
    }

}
