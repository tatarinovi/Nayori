import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls



Item {
    readonly property var nayoriIconButton: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    implicitWidth: size
    implicitHeight: size

    property int size: 44
    property int cornerRadius: 12

    property string buttonIcon: ""
    property string iconFont: nayoriIconButton.pythonTheme.iconFont
    property int iconFontSize: 18
    property real iconOffsetX: 0
    property real iconOffsetY: 0

    property color accentColor: nayoriIconButton.pythonTheme.surface0
    property color textColor: nayoriIconButton.pythonTheme.crust
    property real bgOpacity: 1.0
    property real glassShadow: 1
    readonly property color displayTextColor: (nayoriIconButton.pythonTheme.liquidGlass && (0.2126 * textColor.r + 0.7152 * textColor.g + 0.0722 * textColor.b) < 0.5) ? nayoriIconButton.pythonTheme.text : textColor

    activeFocusOnTab: root.enabled
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            btnMa.clicked({ button: Qt.LeftButton });
            event.accepted = true;
        }
    }

    property bool action_highlight: false
    property string clickSound: "reusables/iconbutton/click.wav"
    property int acceptedButtons: Qt.LeftButton

    signal clicked()
    signal rightClicked()
    signal triggered()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    readonly property bool pressed: btnMa.pressed

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled

    Item {
        id: btnContainer
        anchors.fill: parent

        scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 0.96 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
        Behavior on scale { NumberAnimation { duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 250); easing.type: Easing.OutQuint } }

        SequentialAnimation {
            id: btnPopAnim
            NumberAnimation { target: root; property: "popScale"; to: 1.1; duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 110); easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 400); easing.type: Easing.OutQuint }
        }

        Rectangle {
            id: btnShape
            anchors.fill: parent
            radius: root.cornerRadius
            clip: !glass.active
            color: nayoriIconButton.pythonTheme.liquidGlass ? "transparent" : (!root.enabled ? root.accentColor : (btnMa.pressed ? Qt.darker(root.accentColor, 1.12) : (root.isHoveredOrHighlighted ? Qt.lighter(root.accentColor, 1.12) : root.accentColor)))
            opacity: (root.enabled ? 1.0 : 0.5) * root.bgOpacity

            Behavior on color { ColorAnimation { duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 150) } }
            Behavior on opacity { NumberAnimation { duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 150) } }

            GlassFill {
                id: glass
                anchors.fill: parent
                shadow: root.glassShadow
                press: btnMa.pressed ? 1 : (root.isHoveredOrHighlighted ? 0.25 : 0)
                pulse: Math.min(1, root.flashOpacity * 2.5)
                Behavior on press { NumberAnimation { duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 250); easing.type: Easing.OutCubic } }
                radius: root.cornerRadius
                tintColor: root.accentColor
                tintAmount: btnMa.pressed ? 0.55 : (root.isHoveredOrHighlighted ? 0.42 : 0.3)
                Behavior on tintAmount { NumberAnimation { duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 150) } }
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.iconOffsetX
            anchors.verticalCenterOffset: root.iconOffsetY
            text: root.buttonIcon
            font.family: root.iconFont
            font.pixelSize: Math.round(root.iconFontSize)
            color: root.displayTextColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.5
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            visible: !glass.active
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: (nayoriIconButton && nayoriIconButton.reducedMotion ? 0 : 400); easing.type: Easing.OutExpo }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: root.enabled
            enabled: root.enabled
            acceptedButtons: root.acceptedButtons
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: (mouse) => {
                if (!root.enabled) return;
                if (mouse.button === Qt.RightButton) {
                    root.rightClicked();
                    return;
                }
                btnPopAnim.start();
                root.flashOpacity = 0.4;
                btnFlashAnim.start();
                if (typeof Sounds !== "undefined") {
                    nayoriIconButton.sounds.playSfx(root.clickSound);
                }
                root.clicked();
                root.triggered();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: root.cornerRadius + 2
        color: "transparent"
        visible: root.activeFocus
        z: 100
    }
}
