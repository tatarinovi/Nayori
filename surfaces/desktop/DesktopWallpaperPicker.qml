pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../settings"

ColumnLayout {
    id: root
    required property var tokens
    required property var manager
    required property string output
    spacing: 8

    DesktopLabel {
        Layout.fillWidth: true
        tokens: root.tokens
        text: "Обои · " + root.output
    }
    WallpaperPage {
        id: picker
        objectName: "desktop-wallpaper-picker"
        Layout.fillWidth: true
        Layout.fillHeight: true
        tokens: root.tokens
        manager: root.manager
        output: root.output
        compact: true
        showHeading: false
    }
    RowLayout {
        Layout.fillWidth: true
        SettingsButton {
            objectName: "desktop-wallpaper-cancel"
            Layout.fillWidth: true
            tokens: root.tokens
            text: "Отменить"
            onClicked: picker.cancel()
        }
        SettingsButton {
            objectName: "desktop-wallpaper-apply"
            Layout.fillWidth: true
            tokens: root.tokens
            text: "Применить"
            primary: true
            enabled: picker.canApply
            onClicked: picker.apply()
        }
    }
}
