import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell



Item {
    readonly property var nayoriUserFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 220
    property real minHeight: 130
    property real maxWidth: 500
    property real maxHeight: 300
    property real minAspect: 1.2
    property real maxAspect: 2.8
    property bool isRound: false
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    Rectangle {
        anchors.fill: parent
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriUserFace.pythonTheme.surface0, nayoriUserFace.pythonTheme.elementOpacity)
        radius: nayoriUserFace.pythonTheme.clampedBorderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            visible: !root.ryokuBare
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: nayoriUserFace.scaler.s(10)
            spacing: nayoriUserFace.scaler.s(8)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: nayoriUserFace.scaler.s(10)

                ImageBox {
                    id: avatarBox
                    Layout.preferredWidth: nayoriUserFace.scaler.s(70)
                    Layout.preferredHeight: nayoriUserFace.scaler.s(70)
                    size: nayoriUserFace.scaler.s(70)
                    cornerRadius: nayoriUserFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriUserFace.pythonTheme.borderRadius, nayoriUserFace.scaler.s(12)) : nayoriUserFace.scaler.s(12)
                    imageRadius: cornerRadius
                    source: nayoriUserFace.systemInfo.avatarPath !== "" ? "file://" + nayoriUserFace.systemInfo.avatarPath : ""
                    backgroundColor: nayoriUserFace.systemInfo.avatarPath === "" ? nayoriUserFace.pythonTheme.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: nayoriUserFace.pythonTheme.iconFont
                        font.pixelSize: nayoriUserFace.scaler.s(30)
                        color: nayoriUserFace.pythonTheme.text
                        visible: nayoriUserFace.systemInfo.avatarPath === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: nayoriUserFace.scaler.s(6)

                    ClickButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: nayoriUserFace.scaler.s(32)
                        cornerRadius: nayoriUserFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriUserFace.pythonTheme.borderRadius, nayoriUserFace.scaler.s(8)) : nayoriUserFace.scaler.s(8)
                        horizontalPadding: nayoriUserFace.scaler.s(10)
                        contentAlignment: Qt.AlignLeft
                        buttonIcon: ""
                        iconFontSize: nayoriUserFace.scaler.s(15)
                        buttonText: nayoriUserFace.systemInfo.username !== "" ? nayoriUserFace.systemInfo.username : "User"
                        textFontSize: nayoriUserFace.scaler.s(12)
                        accentColor: nayoriUserFace.pythonTheme.surface1
                        bgOpacity: nayoriUserFace.pythonTheme.elementOpacity
                        textColor: nayoriUserFace.pythonTheme.text
                        onClicked: nayoriUserFace.sessionAction("settings")
                    }

                    ClickButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: nayoriUserFace.scaler.s(32)
                        cornerRadius: nayoriUserFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriUserFace.pythonTheme.borderRadius, nayoriUserFace.scaler.s(8)) : nayoriUserFace.scaler.s(8)
                        horizontalPadding: nayoriUserFace.scaler.s(10)
                        contentAlignment: Qt.AlignLeft
                        buttonIcon: ""
                        iconFontSize: nayoriUserFace.scaler.s(15)
                        buttonText: "Lock"
                        textFontSize: nayoriUserFace.scaler.s(12)
                        accentColor: nayoriUserFace.pythonTheme.surface1
                        bgOpacity: nayoriUserFace.pythonTheme.elementOpacity
                        textColor: nayoriUserFace.pythonTheme.mauve

                        onClicked: nayoriUserFace.sessionAction("lock")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: nayoriUserFace.scaler.s(36)
                spacing: nayoriUserFace.scaler.s(6)

                Repeater {
                    model: [
                        { cmd: "sleep", icon: "󰒲", weight: 1.0, color: nayoriUserFace.pythonTheme.blue },
                        { cmd: "reboot", icon: "󰑓", weight: 2.0, color: nayoriUserFace.pythonTheme.peach },
                        { cmd: "poweroff", icon: "", weight: 3.0, color: nayoriUserFace.pythonTheme.red }
                    ]

                    delegate: Rectangle {
                        id: actionCapsule
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: nayoriUserFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriUserFace.pythonTheme.borderRadius, nayoriUserFace.scaler.s(8)) : nayoriUserFace.scaler.s(8)
                        clip: true

                        property real fillLevel: 0.0
                        property bool triggered: false
                        property real flashOpacity: 0.0
                        property int chargingSoundHandle: -1
                        property color fillColor: modelData.color
                        property real weight: modelData.weight
                        property string cmd: modelData.cmd
                        property string icon: modelData.icon

                        color: Qt.alpha(actionMa.containsMouse ? (nayoriUserFace.pythonTheme.surface2 !== undefined ? nayoriUserFace.pythonTheme.surface2 : Qt.lighter(nayoriUserFace.pythonTheme.surface1, 1.12)) : nayoriUserFace.pythonTheme.surface1, nayoriUserFace.pythonTheme.elementOpacity)
                        Behavior on color {
                            ColorAnimation { duration: (nayoriUserFace.reducedMotion ? 0 : 250) }
                        }

                        scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse ? 1.02 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: (nayoriUserFace.reducedMotion ? 0 : 400); easing.type: Easing.OutQuart }
                        }

                        WaveSurface {
                            anchors.fill: parent
                            visible: actionCapsule.fillLevel > 0.001
                            fill: actionCapsule.fillLevel
                            amp: actionCapsule.fillLevel < 0.99
                                ? nayoriUserFace.scaler.s(8) * Math.sin(actionCapsule.fillLevel * Math.PI) : 0
                            phase: waveClock.phase
                            radius: actionCapsule.radius
                            alpha: 1
                            colorTop: actionCapsule.fillColor
                            colorBottom: actionCapsule.fillColor

                            WaveClock {
                                id: waveClock
                                duration: (nayoriUserFace.reducedMotion ? 0 : 800)
                                running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: actionCapsule.radius
                            color: "#ffffff"
                            opacity: actionCapsule.flashOpacity
                            PropertyAnimation on opacity {
                                id: cardFlashAnim
                                to: 0
                                duration: (nayoriUserFace.reducedMotion ? 0 : 500)
                                easing.type: Easing.OutExpo
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.family: nayoriUserFace.pythonTheme.iconFont
                            font.pixelSize: nayoriUserFace.scaler.s(16)
                            color: actionMa.containsMouse ? nayoriUserFace.pythonTheme.text : nayoriUserFace.pythonTheme.subtext0
                            text: actionCapsule.icon
                            Behavior on color {
                                ColorAnimation { duration: (nayoriUserFace.reducedMotion ? 0 : 150) }
                            }
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: actionCapsule.height * actionCapsule.fillLevel
                            clip: true

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                font.family: nayoriUserFace.pythonTheme.iconFont
                                font.pixelSize: nayoriUserFace.scaler.s(16)
                                color: nayoriUserFace.pythonTheme.crust
                                text: actionCapsule.icon
                            }
                        }

                        MouseArea {
                            id: actionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor

                            onPressed: {
                                if (!actionCapsule.triggered) {
                                    if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                        nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    if (!!nayoriUserFace.sounds) {
                                        actionCapsule.chargingSoundHandle = nayoriUserFace.sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                                    }
                                    drainAnim.stop();
                                    fillAnim.start();
                                }
                            }

                            onReleased: {
                                if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) {
                                    if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                        nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    fillAnim.stop();
                                    drainAnim.start();
                                }
                            }

                            onCanceled: {
                                if (!actionCapsule.triggered) {
                                    if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                        nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                        actionCapsule.chargingSoundHandle = -1;
                                    }
                                    fillAnim.stop();
                                    drainAnim.start();
                                }
                            }
                        }

                        NumberAnimation {
                            id: fillAnim
                            target: actionCapsule
                            property: "fillLevel"
                            to: 1.0
                            duration: (550 * weight) * (1.0 - actionCapsule.fillLevel)
                            easing.type: Easing.InSine
                            onFinished: {
                                actionCapsule.triggered = true;
                                actionCapsule.flashOpacity = 0.6;
                                if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                    nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                    actionCapsule.chargingSoundHandle = -1;
                                }
                                if (!!nayoriUserFace.sounds) {
                                    nayoriUserFace.sounds.playSfx("reusables/fillbutton/button.wav");
                                }
                                cardFlashAnim.start();
                                drainAnim.start();
                                exitTimer.start();
                            }
                        }

                        NumberAnimation {
                            id: drainAnim
                            target: actionCapsule
                            property: "fillLevel"
                            to: 0.0
                            duration: (nayoriUserFace.reducedMotion ? 0 : 1500) * actionCapsule.fillLevel
                            easing.type: Easing.OutQuad
                        }

                        Timer {
                            id: exitTimer
                            interval: 450
                            onTriggered: {
                                if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                    nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                    actionCapsule.chargingSoundHandle = -1;
                                }
                                if (cmd === "sleep") {
                                    nayoriUserFace.sessionAction("sleep");
                                } else if (cmd === "reboot") {
                                    nayoriUserFace.sessionAction("reboot");
                                } else if (cmd === "poweroff") {
                                    nayoriUserFace.sessionAction("poweroff");
                                }
                                actionCapsule.fillLevel = 0.0;
                                actionCapsule.triggered = false;
                            }
                        }

                        Component.onDestruction: {
                            if (actionCapsule.chargingSoundHandle !== -1 && !!nayoriUserFace.sounds) {
                                nayoriUserFace.sounds.stopSfx(actionCapsule.chargingSoundHandle);
                                actionCapsule.chargingSoundHandle = -1;
                            }
                        }
                    }
                }
            }
        }
    }
}
