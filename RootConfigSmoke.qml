import QtQuick
import Quickshell
// These imports populate Quickshell VFS dependencies for the dynamic root compilation.
// qmllint disable unused-imports
import "tokens"
import "services/niri"
import "services/settings"
import "services/weather"
import "surfaces/launcher"
import "surfaces/settings"
import "surfaces/panel"
import "services/canvas"
import "services/island"
import "surfaces/canvas"
// qmllint enable unused-imports

// Compile the actual entrypoint without instantiating its desktop surfaces.
ShellRoot {
    id: test
    property bool animations: true
    Tokens { id: theme; animationsEnabled: test.animations }
    Timer { interval: 1; running: true; onTriggered: {
        const component = Qt.createComponent(Qt.resolvedUrl("shell.qml"))
        if (component.status !== Component.Ready) {
            console.error("ROOT_CONFIG_FAIL " + component.errorString())
            Qt.exit(1)
            return
        }
        if (theme.motion.off) { console.error("ROOT_CONFIG_FAIL motion initial binding"); Qt.exit(1); return }
        test.animations = false
        if (!theme.motion.off) { console.error("ROOT_CONFIG_FAIL motion update"); Qt.exit(1); return }
        test.animations = true
        if (theme.motion.off) { console.error("ROOT_CONFIG_FAIL motion restore"); Qt.exit(1); return }
        console.log("ROOT_CONFIG_PASS")
        Qt.quit()
    } }
}
