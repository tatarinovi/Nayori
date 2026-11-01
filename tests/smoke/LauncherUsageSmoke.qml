import QtQuick
import Quickshell
import "services"
import "services/launcher"

ShellRoot {
    id: root
    property int ticks: 0
    LauncherUsage { id: usage; storageDirectory: Quickshell.env("NAYORI_USAGE_DIR") }
    Apps { id: apps; launchCounts: usage.counts }
    Component.onCompleted: {
        usage.record("alpha.desktop")
        usage.record("alpha.desktop")
        usage.record("beta.desktop")
        usage.record("__proto__")
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (!usage.ready || !apps.catalogReady) {
                if (++root.ticks > 60) { console.error("LAUNCHER_USAGE_FAIL timeout"); Qt.quit() }
                return
            }
            if (usage.counts["alpha.desktop"] < 2 || usage.topKeys(1)[0] !== "alpha.desktop")
                throw new Error("frequency")
            const top = apps.collectFrequent(usage.counts, usage.lastVisited, apps.generation)
            if (top.length !== 2 || top[0].id.indexOf("alpha") < 0)
                throw new Error("frequent apps: " + JSON.stringify(top))
            apps.query = "example"
            if (apps.results.length < 2 || apps.results[0].id.indexOf("alpha") < 0)
                throw new Error("search frequency: " + JSON.stringify(apps.results))
            usage.record("beta.desktop")
            if (usage.counts["alpha.desktop"] === usage.counts["beta.desktop"] && usage.topKeys(1)[0] !== "beta.desktop")
                throw new Error("recency")
            if (apps.collectFrequent({"missing.desktop": 100}, {}, apps.generation).length !== 0)
                throw new Error("missing entry")
            usage.flush(true)
            console.log("LAUNCHER_USAGE_PASS")
            Qt.quit()
        }
    }
}
