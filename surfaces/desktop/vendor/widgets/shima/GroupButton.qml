import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.





import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 button with expressive bounciness. 
 * See https://m3.material.io/components/button-groups/overview
 */
Button {
    readonly property var nayoriGroupButton: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    property bool toggled
    property string buttonText
    property real buttonRadius: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.controlRadius
        : (nayoriGroupButton.appearance?.rounding?.small ?? 8)
    property real buttonRadiusPressed: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.controlRadius
        : (nayoriGroupButton.appearance?.rounding?.small ?? 6)
    property var downAction // When left clicking (down)
    property var releaseAction // When left clicking (release)
    property var altAction // When right clicking
    property var middleClickAction // When middle clicking
    property bool bounce: !nayoriGroupButton.appearance.regaliaEverywhere && !nayoriGroupButton.appearance.editorialEverywhere
    // Cookie Shapes: an organic face costs a Canvas, and a segmented group needs
    // its members to share one continuous silhouette. Standalone semantic
    // controls opt in; grouped ones stay rectangular on purpose.
    property bool cookieMorphing: false
    property real baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    property real baseHeight: nayoriGroupButton.appearance.regaliaEverywhere
        ? Math.max(nayoriGroupButton.appearance.regalia.compactControlHeight, contentItem.implicitHeight + verticalPadding * 2)
        : contentItem.implicitHeight + verticalPadding * 2
    property bool enableImplicitWidthAnimation: true
    property bool enableImplicitHeightAnimation: true
    property real clickedWidth: baseWidth + (isAtSide ? 10 : 20)
    property real clickedHeight: baseHeight
    property var parentGroup: root.parent
    property int indexInParent: parentGroup?.children.indexOf(root) ?? -1
    property int clickIndex: parentGroup?.clickIndex ?? -1
    property bool isAtSide: indexInParent === 0 || indexInParent === (parentGroup?.childrenCount - 1)

    // Bounce stretch only while a press is active. With clickIndex at the idle
    // value -1 the raw interval test also matched the first child, permanently
    // stretching it and starving its siblings (disproportionate quick controls).
    property bool clickStretch: root.clickIndex >= 0
        && (root.clickIndex - 1 <= root.indexInParent && root.indexInParent <= root.clickIndex + 1)
    Layout.fillWidth: root.clickStretch
    Layout.fillHeight: root.clickStretch
    implicitWidth: (root.down && bounce) ? clickedWidth : baseWidth
    implicitHeight: (root.down && bounce) ? clickedHeight : baseHeight

    property color colBackground: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.controlPlate
        : (nayoriGroupButton.colorUtils.transparentize(colBackgroundHover, 1) || "transparent")
    property color colBackgroundHover: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.controlPlateHover : nayoriGroupButton.appearance.colors.colLayer1Hover
    property color colBackgroundActive: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.controlPlateActive : nayoriGroupButton.appearance.colors.colLayer1Active
    property color colBackgroundToggled: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.primaryPlate
        : nayoriGroupButton.appearance.zzzEverywhere ? nayoriGroupButton.appearance.zzz.sticker : nayoriGroupButton.appearance.colors.colPrimary
    property color colBackgroundToggledHover: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.primaryPlateHover : nayoriGroupButton.appearance.colors.colPrimaryHover
    property color colBackgroundToggledActive: nayoriGroupButton.appearance.regaliaEverywhere ? nayoriGroupButton.appearance.regalia.primaryPlateActive : nayoriGroupButton.appearance.colors.colPrimaryActive

    property real radius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real leftRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real rightRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property color color: root.enabled ? (root.toggled ? 
        (root.down ? colBackgroundToggledActive : 
            root.hovered ? colBackgroundToggledHover : 
            colBackgroundToggled) :
        (root.down ? colBackgroundActive : 
            root.hovered ? colBackgroundHover : 
            colBackground)) : colBackground

    onDownChanged: {
        if (root.down) {
            if (root.parent.clickIndex !== undefined) {
                root.parent.clickIndex = parent.children.indexOf(root)
            }
        }
    }

    Behavior on implicitWidth {
        enabled: root.enableImplicitWidthAnimation
        animation: NumberAnimation { duration: nayoriGroupButton.appearance.animation.clickBounce.duration; easing.type: nayoriGroupButton.appearance.animation.clickBounce.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.clickBounce.bezierCurve }
    }

    Behavior on implicitHeight {
        enabled: root.enableImplicitHeightAnimation
        animation: NumberAnimation { duration: nayoriGroupButton.appearance.animation.clickBounce.duration; easing.type: nayoriGroupButton.appearance.animation.clickBounce.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.clickBounce.bezierCurve }
    }

    Behavior on leftRadius {
        enabled: nayoriGroupButton.appearance.animationsEnabled
        animation: NumberAnimation { duration: nayoriGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on rightRadius {
        enabled: nayoriGroupButton.appearance.animationsEnabled
        animation: NumberAnimation { duration: nayoriGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.elementMoveFast.bezierCurve }
    }

    // TapHandler for right-click (altAction) - works better with Button control
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (root.altAction) root.altAction();
        }
    }

    // TapHandler for middle-click
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (root.middleClickAction) root.middleClickAction();
        }
    }

    // TapHandler for long-press (also triggers altAction)
    TapHandler {
        acceptedButtons: Qt.LeftButton
        longPressThreshold: 0.5
        onLongPressed: {
            if (root.altAction) root.altAction();
        }
    }

    // MouseArea only for cursor shape and left-click handling
    property alias mouseArea: buttonMouseArea
    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: (event) => { 
            root.down = true
            if (root.downAction) root.downAction();
        }
        onReleased: (event) => {
            root.down = false
            if (root.releaseAction) root.releaseAction();
        }
        onClicked: (event) => {
            root.clicked()
        }
        onCanceled: (event) => {
            root.down = false
        }
    }


    background: Rectangle {
        id: buttonBackground
        readonly property bool cookieFace: nayoriGroupButton.appearance.cookieEverywhere && root.cookieMorphing
        topLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomLeftRadius: root.leftRadius
        bottomRightRadius: root.rightRadius
        implicitHeight: 50

        color: buttonBackground.cookieFace || nayoriGroupButton.appearance.regaliaEverywhere
            ? "transparent" : root.color
        border.width: nayoriGroupButton.appearance.editorialEverywhere ? (root.visualFocus ? 2 : 1) : 0
        border.color: nayoriGroupButton.appearance.editorialEverywhere
            ? (root.visualFocus ? nayoriGroupButton.appearance.editorial.focusRing
                : root.hovered || root.down ? nayoriGroupButton.appearance.editorial.edge : "transparent")
            : "transparent"
        scale: nayoriGroupButton.appearance.regaliaEverywhere && root.down ? nayoriGroupButton.appearance.regalia.pressScale : 1
        Behavior on scale {
            enabled: nayoriGroupButton.appearance.animationsEnabled && nayoriGroupButton.appearance.regaliaEverywhere
            NumberAnimation { duration: nayoriGroupButton.appearance.regalia.pressDuration; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            enabled: nayoriGroupButton.appearance.animationsEnabled
            animation: ColorAnimation { duration: nayoriGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.elementMoveFast.bezierCurve }
        }

        RegaliaControlFace {
            anchors.fill: parent
            visible: nayoriGroupButton.appearance.regaliaEverywhere
            fillColor: root.color
            radius: root.radius
            selected: root.toggled
            focused: root.visualFocus
        }

        // The face carries the toggled state as topology (pill → cookie), so the
        // colour is all this needs; press/hover stay on colour and the bounce.
        // Keyboard focus is a ring on that same silhouette.
        Loader {
            anchors.fill: parent
            active: buttonBackground.cookieFace
            sourceComponent: CookieFace {
                role: "control"
                selected: root.toggled
                color: root.color
                strokeColor: root.visualFocus ? nayoriGroupButton.appearance.colors.colPrimary : "transparent"
                strokeWidth: root.visualFocus ? 2 : 0
            }
        }
    }

    contentItem: StyledText {
        text: root.buttonText
        font.weight: nayoriGroupButton.appearance.editorialEverywhere ? nayoriGroupButton.appearance.editorial.labelWeight : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        // ZZZ selected = sticker plate → onSticker ink; idle = panel ink. Keeps
        // tab/segment labels readable instead of washed default ink on a pop plate.
        color: nayoriGroupButton.appearance.regaliaEverywhere
            ? (root.toggled ? nayoriGroupButton.appearance.regalia.primaryPlateInk : nayoriGroupButton.appearance.regalia.onColor)
            : nayoriGroupButton.appearance.zzzEverywhere
                ? (root.toggled ? nayoriGroupButton.appearance.zzz.onSticker : nayoriGroupButton.appearance.zzz.ink)
                : nayoriGroupButton.appearance.editorialEverywhere
                    ? (root.toggled ? nayoriGroupButton.appearance.editorial.accentInk : nayoriGroupButton.appearance.editorial.ink)
                : nayoriGroupButton.appearance.colors.colOnLayer0
        Behavior on color {
            enabled: nayoriGroupButton.appearance.animationsEnabled
            ColorAnimation { duration: nayoriGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriGroupButton.appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
