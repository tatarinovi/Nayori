pragma ComponentBehavior: Bound
import QtQuick

// Non-interactive faces share their data and placement with the input layer.
Item {
    id: root
    required property var tokens
    property var items: []
    property var hiddenIds: []
    property date now: new Date()
    property var weatherService: null
    property var music: null
    property var systemReader: null

    Repeater {
        model: root.items
        delegate: DesktopWidgetFrame {
            required property var modelData
            tokens: root.tokens
            spec: modelData
            visible: !!modelData && root.hiddenIds.indexOf(modelData.id) < 0
            screenWidth: root.width
            screenHeight: root.height
            now: root.now
            weatherService: root.weatherService
            music: root.music
            systemReader: root.systemReader
        }
    }
}
