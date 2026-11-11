import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io



Item {
    readonly property var nayoriWeatherFaceCompact: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.7
    property real maxAspect: 2.2
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property real dynMargin: Math.max(6, Math.min(16, Math.min(root.width, root.height) * 0.08))
    property real dynSpacing: Math.max(2, Math.min(8, Math.min(root.width, root.height) * 0.04))

    property var weatherData: nayoriWeatherFaceCompact.weather.data
    property bool hasLoadedOnce: nayoriWeatherFaceCompact.weather.isReady
    property bool isLoading: nayoriWeatherFaceCompact.weather.isLoading || !nayoriWeatherFaceCompact.weather.isReady

    property string currentHex: nayoriWeatherFaceCompact.weather.currentHex
    property color accentColor: (currentHex && currentHex.length === 7) ? currentHex : nayoriWeatherFaceCompact.pythonTheme.mauve

    Rectangle {
        anchors.fill: parent
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriWeatherFaceCompact.pythonTheme.surface0, nayoriWeatherFaceCompact.pythonTheme.elementOpacity)
        radius: nayoriWeatherFaceCompact.pythonTheme.borderRadius * 2

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: nayoriWeatherFaceCompact.pythonTheme.borderRadius * 2
            visible: !root.ryokuBare
        }
    }

    LoaderIcon {
        anchors.centerIn: parent
        width: Math.max(20, Math.min(44, Math.min(root.width, root.height) * 0.4))
        height: width
        accentColor: nayoriWeatherFaceCompact.pythonTheme.mauve
        running: root.isLoading
        visible: root.isLoading
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: root.dynMargin
        property bool isHorizontal: root.width > root.height * 1.15
        columns: isHorizontal ? 2 : 1
        rows: isHorizontal ? 1 : 2
        columnSpacing: root.dynSpacing
        rowSpacing: root.dynSpacing
        visible: !root.isLoading

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: parent.isHorizontal ? parent.width * 0.5 : parent.width
            Layout.preferredHeight: parent.isHorizontal ? parent.height : parent.height * 0.5

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -6
                text: nayoriWeatherFaceCompact.weather.currentIcon !== "" ? nayoriWeatherFaceCompact.weather.currentIcon : ""
                font.family: nayoriWeatherFaceCompact.pythonTheme.fontFamily
                font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.65)
                color: root.accentColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: parent.isHorizontal ? parent.width * 0.5 : parent.width
            Layout.preferredHeight: parent.isHorizontal ? parent.height : parent.height * 0.5

            Text {
                anchors.centerIn: parent
                text: nayoriWeatherFaceCompact.weather.currentTemp !== "" ? Math.round(parseFloat(nayoriWeatherFaceCompact.weather.currentTemp)) + "°" : "--°"
                font.family: nayoriWeatherFaceCompact.pythonTheme.fontFamily
                font.pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.45)
                font.weight: Font.Black
                color: nayoriWeatherFaceCompact.pythonTheme.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
