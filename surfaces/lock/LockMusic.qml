pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../sddm/nayori/components"
import "../island"

ColumnLayout {
    id: root
    required property var colors
    required property var music
    readonly property var player: music ? music.player : null
    visible: player !== null
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 56; implicitHeight: 56; radius: 8
            color: root.colors.surfaceAlt
            clip: true
            Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.player ? root.player.trackTitle : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.colors.text; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: root.player ? root.player.trackArtist : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.colors.textMuted; font.family: "Inter"; font.pixelSize: 12 }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 3
        radius: 2
        color: root.colors.surface
        visible: root.player && root.player.positionSupported && root.player.length > 0
        Rectangle {
            height: parent.height
            radius: 2
            width: parent.width * Math.max(0, Math.min(1, root.music.position / Math.max(1, root.player ? root.player.length : 0)))
            color: root.colors.accent
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["prev", "play", "next"]
            AuthButton {
                id: control
                required property string modelData
                Layout.fillWidth: true
                implicitWidth: 0
                colors: root.colors
                filled: modelData === "play"
                Accessible.name: modelData === "prev" ? "Предыдущий трек" : modelData === "next" ? "Следующий трек" : root.player && root.player.isPlaying ? "Приостановить" : "Воспроизвести"
                enabled: !!root.player && (modelData === "prev" ? root.player.canGoPrevious : modelData === "next" ? root.player.canGoNext : root.player.canTogglePlaying)
                contentItem: Item {
                    MusicTransportIcon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        name: control.modelData === "play" ? root.player && root.player.isPlaying ? "pause" : "play" : control.modelData
                        ink: control.filled ? root.colors.accentText : root.colors.text
                        opacity: control.enabled ? 1 : 0.4
                    }
                }
                onClicked: {
                    if (modelData === "prev") root.player.previous()
                    else if (modelData === "next") root.player.next()
                    else root.player.togglePlaying()
                }
            }
        }
    }
}
