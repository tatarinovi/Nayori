import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.

import QtQuick

Text {
    readonly property var nayoriStyledText: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property bool animateChange: false
    property real animationDistanceX: 0
    property real animationDistanceY: 6

    property real _slideX: 0
    property real _slideY: 0
    Translate {
        id: slideTransform
        x: root._slideX
        y: root._slideY
    }
    transform: root.animateChange ? [slideTransform] : []

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    property var defaultFont: shouldUseNumberFont ? nayoriStyledText.appearance.font.family.numbers : nayoriStyledText.appearance.font.family.main

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: defaultFont
        pixelSize: nayoriStyledText.appearance?.font.pixelSize.small ?? 15
        variableAxes: shouldUseNumberFont ? ({}) : nayoriStyledText.appearance.font.variableAxes.main
        features: shouldUseNumberFont ? ({ "tnum": 1 }) : ({})
        // ZZZ poster crispness: a small global letter-spacing under the zzz style
        // (token-driven, absolute px). Numbers stay untracked so digit columns
        // don't drift. Other styles unaffected (0).
        letterSpacing: (nayoriStyledText.appearance?.zzzEverywhere && !root.shouldUseNumberFont)
            ? (nayoriStyledText.appearance?.zzz.tracking ?? 0)
            : (nayoriStyledText.appearance?.regaliaEverywhere && !root.shouldUseNumberFont) ? 0.12 : 0
    }
    color: nayoriStyledText.appearance?.colors.colOnLayer0 ?? "black"
    linkColor: nayoriStyledText.appearance?.colors.colPrimary

    component Anim: NumberAnimation {
        target: root
        duration: nayoriStyledText.appearance.animation.elementMoveFast.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: nayoriStyledText.appearance.animation.elementMoveFast.bezierCurve
    }

    Behavior on text {
        enabled: root.animateChange && nayoriStyledText.appearance.animationsEnabled

        SequentialAnimation {
            alwaysRunToEnd: true

            ParallelAnimation {
                Anim {
                    property: "_slideX"
                    to: -root.animationDistanceX
                    easing.type: Easing.InSine
                }
                Anim {
                    property: "_slideY"
                    to: -root.animationDistanceY
                    easing.type: Easing.InSine
                }
                Anim {
                    property: "opacity"
                    to: 0
                    easing.type: Easing.InSine
                }
            }
            PropertyAction {} // Tie the text update to this point (we don't want it to happen during the first slide+fade)
            PropertyAction {
                target: root
                property: "_slideX"
                value: root.animationDistanceX
            }
            PropertyAction {
                target: root
                property: "_slideY"
                value: root.animationDistanceY
            }
            ParallelAnimation {
                Anim {
                    property: "_slideX"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    property: "_slideY"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    property: "opacity"
                    to: 1
                    easing.type: Easing.OutSine
                }
            }
        }
    }
}
