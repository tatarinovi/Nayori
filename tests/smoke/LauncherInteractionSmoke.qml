import QtQuick
import Quickshell
import "tokens"
import "surfaces/launcher"

ShellRoot {
    id: root
    property int ticks: 0
    property string launchedId: ""
    Tokens { id: theme }
    Item {
        width: 640; height: 600
        Launcher {
            id: launcher
            width: 640
            tokens: theme
            embedded: true
            onLaunched: function(id) { root.launchedId = id }
        }
        LauncherDropdown {
            id: dropdown
            y: 50; width: 600
            tokens: theme
            host: launcher
        }
    }
    function findItems(item, name) {
        let found = []
        if (item.objectName === name) found.push(item)
        if (item.children) {
            for (let i = 0; i < item.children.length; i++)
                found = found.concat(findItems(item.children[i], name))
        }
        return found
    }
    Component.onCompleted: launcher.open()
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (launcher.rows.length !== 2 || root.findItems(dropdown, "launcher-row-mouse").length !== 2) {
                if (++root.ticks > 100) { console.error("INTERACTION_FAIL load timeout"); Qt.quit() }
                return
            }
            running = false
            if (launcher.searching || !launcher.listWanted) throw new Error("empty query list")
            const results = root.findItems(dropdown, "launcher-dropdown-results")[0]
            if (results.selectedIndex !== 0) throw new Error("initial selection")
            let event = {key: Qt.Key_Down, modifiers: 0, accepted: false}
            launcher.handleKey(event)
            if (!event.accepted || launcher.selectedIndex !== 1 || results.selectedIndex !== 1)
                throw new Error("down selection")
            event = {key: Qt.Key_Return, modifiers: 0, accepted: false}
            launcher.handleKey(event)
            if (!event.accepted || root.launchedId.indexOf("beta") < 0 || launcher.opened)
                throw new Error("keyboard activation " + root.launchedId)
            launcher.open()
            root.launchedId = ""
            const mouse = root.findItems(dropdown, "launcher-row-mouse")[1]
            results.highlighted(1)
            if (launcher.selectedIndex !== 1 || results.selectedIndex !== 1)
                throw new Error("pointer selection")
            const clickedId = launcher.rows[1].id
            mouse.clicked(null)
            if (root.launchedId !== clickedId || launcher.opened)
                throw new Error("pointer activation " + root.launchedId)
            console.log("LAUNCHER_INTERACTION_PASS")
            Qt.quit()
        }
    }
}
