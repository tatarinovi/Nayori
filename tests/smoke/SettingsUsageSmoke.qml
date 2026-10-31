import QtQuick
import Quickshell
import "services/settings"

ShellRoot {
    id: root
    property int ticks: 0
    SettingsUsage {
        id: usage
        storageDirectory: Quickshell.env("NAYORI_USAGE_DIR")
    }
    Component.onCompleted: {
        // Exercise visits arriving before asynchronous initial read completes.
        usage.record("sound");
        usage.record("sound");
        usage.record("integrations");
        usage.record("display");
        usage.record("home");
        usage.record("not-a-section");
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            root.ticks++;
            if (!usage.ready) {
                if (root.ticks > 60) { console.error("USAGE_FAIL load timeout"); Qt.quit(); }
                return;
            }
            if (root.ticks < 10) return;
            if (usage.counts.sound < 2 || usage.counts.display < 1 || usage.counts.integrations < 1 || usage.counts.home || usage.counts["not-a-section"] || usage.topKeys(1)[0] !== "sound") {
                console.error("USAGE_FAIL counts", JSON.stringify(usage.counts)); Qt.quit(); return;
            }
            if (usage.recentKeys(1)[0] !== "display" || usage.recentKeys(0).length !== 0) {
                console.error("USAGE_FAIL recent sections are independent of frequency"); Qt.quit(); return;
            }
            usage.record("display");
            if (usage.counts.sound === usage.counts.display && usage.topKeys(1)[0] !== "display") {
                console.error("USAGE_FAIL recency tie"); Qt.quit(); return;
            }
            usage.flush(true);
            console.log("USAGE_PASS", usage.state);
            Qt.quit();
        }
    }
}
