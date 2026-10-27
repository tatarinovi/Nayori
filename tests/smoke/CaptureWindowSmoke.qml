pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtTest as Test
import "tokens"
import "services/capture"
import "services/settings"
import "services/island"
import "surfaces/capture"

ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: false }
    SettingsService { id: settingsStore; storageDirectory: Quickshell.env("NAYORI_CAPTURE_TEST_DIR") + "/settings" }
    NotificationModel { id: notificationStore }
    CaptureService { id: capture; settings: settingsStore; notifications: notificationStore }
    PanelWindow {
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#243344"
        WlrLayershell.layer: WlrLayer.Background
        Text { anchors.centerIn: parent; text: "Nayori capture fixture"; color: "white"; font.pixelSize: 32 }
    }
    CaptureOverlay { id: overlay; screen: Quickshell.screens[0]; outputName: Quickshell.screens[0].name; service: capture; tokens: theme }
    PanelWindow {
        anchors.top: true
        margins.top: 8
        implicitWidth: capsule.width; implicitHeight: 48
        visible: capture.controlsVisible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        CaptureCapsule { id: capsule; tokens: theme; service: capture }
    }
    Test.TestCase { id: input; when: false }
    IpcHandler {
        target: "capture_test"
        function begin(): void {
            settingsStore.update({captureShotDir: Quickshell.env("NAYORI_CAPTURE_TEST_DIR") + "/shots"})
            capture.begin("shot", Quickshell.screens[0].name)
        }
        function selectArea(): void { capture.select({x: 250, y: 300, w: 400, h: 240}); capture.next() }
        function annotate(): void {
            capture.addMark({tool: "rect", x: 280, y: 320, ex: 500, ey: 380})
            capture.addMark({tool: "arrow", x: 300, y: 490, ex: 480, ey: 390})
            capture.addMark({tool: "text", x: 280, y: 490, text: "Тест разметки"})
            capture.addMark({tool: "blur", x: 500, y: 380, ex: 630, ey: 450})
        }
        function keys(): void {
            input.keyClick(Qt.Key_B)
            if (capture.tool !== "blur") throw new Error("B tool")
            input.keyClick(Qt.Key_R)
            if (capture.tool !== "rect") throw new Error("R tool")
            input.keyClick(Qt.Key_T)
            if (capture.tool !== "text") throw new Error("T tool")
            input.keyClick(Qt.Key_A)
            if (capture.tool !== "arrow") throw new Error("A tool")
            const before = capture.marks.length
            input.keyClick(Qt.Key_Z, Qt.ControlModifier)
            if (capture.marks.length !== before - 1) throw new Error("Undo")
            input.keyClick(Qt.Key_Y, Qt.ControlModifier)
            if (capture.marks.length !== before) throw new Error("Redo")
        }
        function save(): void { capture.save(true) }
        function cancel(): void { capture.cancel() }
        function snapshot(): string {
            return JSON.stringify({state: capture.state, ready: capture.ready, source: capture.source, error: capture.error,
                focused: overlay.contentItem.activeFocus, marks: capture.marks.length,
                notifications: notificationStore.records.map(r => ({summary: r.summary, body: r.body})), output: capture.output})
        }
    }
}
