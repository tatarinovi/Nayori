pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../services/island/NotificationList.js" as List
import "../../services/island/NotificationSources.js" as Sources

// Значок источника: иконка приложения из темы, иначе плитка с рисованным значком.
Item {
    id: root
    required property var tokens
    // Запись уведомления: appName, appIcon, desktopEntry.
    property var record: ({})
    property int size: 36
    implicitWidth: size
    implicitHeight: size
    readonly property var style: List.sourceStyle(record, Sources.sourceStyles())
    readonly property color tone: style && style.tone === "warning" ? tokens.color.secondary : tokens.color.accent
    readonly property string source: {
        const names = [record.appIcon, record.desktopEntry]
        for (let i = 0; i < names.length; i++) {
            const name = String(names[i] || "")
            if (!name) continue
            if (name.indexOf("/") === 0) return "file://" + name
            if (name.indexOf("file:") === 0) return name
            const found = Quickshell.iconPath(name, true)
            if (found) return found
        }
        return ""
    }
    readonly property bool themed: source !== "" && icon.status === Image.Ready
    Image {
        id: icon
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: root.themed
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.themed
        radius: width / 2
        color: Qt.alpha(root.tone, 0.16)
        border.width: 1
        border.color: Qt.alpha(root.tone, 0.5)
        Glyph {
            anchors.centerIn: parent
            width: Math.round(root.size * 0.5); height: width
            name: root.style ? root.style.glyph : "bell"
            ink: root.tone
            fill: Qt.alpha(root.tone, 0.85)
        }
    }
}
