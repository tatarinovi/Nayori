import QtQuick
import Quickshell
import "surfaces/island"
import "tokens"
ShellRoot {
    Tokens { id: theme }
    SystemPage { tokens: theme; width: 600; height: 500 }
    MorphingIsland { tokens: theme; testMode: true; active: false }
    Timer { interval: 500; running: true; onTriggered: { console.log("SYSTEM_PAGE_LOAD_PASS"); Qt.quit() } }
}
