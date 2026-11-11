import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io



Item {
    readonly property var nayoriWeatherFaceRound: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property real faceSize: Math.min(root.width, root.height)
    property real pillLength: root.faceSize * 0.94
    property real pillWidth: root.faceSize * 0.54
    property real pillRadius: root.pillWidth / 2
    property real iconHorizontalOffset: -12

    property var weatherData: nayoriWeatherFaceRound.weather.data
    property bool hasLoadedOnce: nayoriWeatherFaceRound.weather.isReady
    property bool isLoading: nayoriWeatherFaceRound.weather.isLoading || !nayoriWeatherFaceRound.weather.isReady

    property string currentHex: nayoriWeatherFaceRound.weather.currentHex
    property color accentColor: (currentHex && currentHex.length === 7) ? currentHex : nayoriWeatherFaceRound.pythonTheme.mauve

    property string tempNumber: {
        if (!nayoriWeatherFaceRound.weather.isReady || nayoriWeatherFaceRound.weather.currentTemp === "") {
            return "--";
        }
        let raw = String(nayoriWeatherFaceRound.weather.currentTemp).trim();
        if (raw === "") return "--";

        let num = Math.round(parseFloat(raw));
        if (isNaN(num)) return "--";

        return String(num);
    }

    property string formattedTemp: root.tempNumber + "°"

    Rectangle {
        id: pillBackground
        anchors.centerIn: parent
        width: root.pillWidth
        height: root.pillLength
        radius: root.pillRadius
        rotation: 45
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriWeatherFaceRound.pythonTheme.surface0, nayoriWeatherFaceRound.pythonTheme.elementOpacity)
        antialiasing: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            visible: !root.ryokuBare
        }

        Item {
            anchors.fill: parent
            rotation: -45
            visible: root.isLoading

            LoaderIcon {
                anchors.centerIn: parent
                width: root.pillWidth * 0.45
                height: width
                accentColor: nayoriWeatherFaceRound.pythonTheme.mauve
                running: root.isLoading
                visible: root.isLoading
            }
        }

        Item {
            anchors.fill: parent
            visible: !root.isLoading

            Item {
                id: iconContainer
                width: root.pillWidth * 0.68
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: root.pillRadius
                rotation: -45

                Text {
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.iconHorizontalOffset
                    text: nayoriWeatherFaceRound.weather.currentIcon !== "" ? nayoriWeatherFaceRound.weather.currentIcon : ""
                    font.family: nayoriWeatherFaceRound.pythonTheme.fontFamily
                    font.pixelSize: Math.round(parent.height * 0.76)
                    color: root.accentColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 8
                }
            }

            Item {
                id: tempContainer
                width: root.pillWidth * 0.68
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.bottom
                anchors.verticalCenterOffset: -root.pillRadius
                rotation: -45

                Item {
                    anchors.centerIn: parent
                    width: tempNumberText.implicitWidth
                    height: tempNumberText.implicitHeight

                    Text {
                        id: tempNumberText
                        anchors.centerIn: parent
                        text: root.tempNumber
                        font.family: nayoriWeatherFaceRound.pythonTheme.fontFamily
                        font.weight: Font.Black
                        color: nayoriWeatherFaceRound.pythonTheme.text
                        font.pixelSize: Math.round(tempContainer.height * 0.58)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: degreeText
                        anchors.left: tempNumberText.right
                        anchors.leftMargin: 1
                        anchors.top: tempNumberText.top
                        anchors.topMargin: tempContainer.height * 0.04
                        text: "°"
                        font.family: nayoriWeatherFaceRound.pythonTheme.fontFamily
                        font.weight: Font.Bold
                        color: nayoriWeatherFaceRound.pythonTheme.text
                        font.pixelSize: Math.round(tempContainer.height * 0.30)
                    }
                }
            }
        }
    }
}
