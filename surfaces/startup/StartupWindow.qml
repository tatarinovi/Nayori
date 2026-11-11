import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var startup
    required property var tokens
    property string outputName: screen ? screen.name : ""
    property color splashAccent: tokens.color.accent
    property bool dynamicAccent: true
    property int fadeDuration: 220
    property string waitingFor: "компоненты оболочки"
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    // Cover input as well as pixels while unfinished shell surfaces are mapped.
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-startup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    StartupCover {
        anchors.fill: parent
        startup: root.startup
        tokens: root.tokens
        outputName: root.outputName
        splashAccent: root.splashAccent
        dynamicAccent: root.dynamicAccent
        fadeDuration: root.fadeDuration
        waitingFor: root.waitingFor
    }
}
