import QtQuick
import Quickshell
import Quickshell.Io

// Shell-owned visit history. Independent from settings.json and any settings window.
QtObject {
    id: root

    property string storageDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/nayori"
    property var counts: ({})
    property var lastVisited: ({})
    readonly property var knownKeys: ["display", "sound", "power", "network", "localsend", "bluetooth", "mouse", "keyboard", "shortcuts", "appearance", "wallpapers", "panels", "start", "island", "lockscreen", "weather", "windows", "alttab", "workspaces", "defaults", "capture", "autostart", "updates", "about", "naomi", "naomi-look", "naomi-place"]
    property bool ready: false
    property string state: "loading"
    property bool dirty: false
    property bool saving: false
    property bool writeFailed: false
    property int revision: 0
    property int savedRevision: 0
    property double sequence: 0
    property var pendingVisits: []
    property var document: ({version: 1})

    property Timer debounce: Timer {
        interval: 250
        onTriggered: root.flush(false)
    }
    property Process directory: Process {
        command: ["mkdir", "-p", "--", root.storageDirectory]
        running: true
        onExited: root.file.path = root.storageDirectory + "/settings-usage.json"
    }
    property FileView file: FileView {
        atomicWrites: true
        printErrors: false
        watchChanges: false
        onLoaded: root.restore(text())
        onLoadFailed: function(error) {
            if (root.ready) return;
            root.finishLoading(error === FileViewError.FileNotFound ? "writable" : "unreadable");
        }
        onSaved: {
            root.saving = false;
            root.dirty = root.revision !== root.savedRevision;
            if (root.dirty) root.debounce.restart();
        }
        onSaveFailed: {
            root.saving = false;
            root.dirty = true;
            root.writeFailed = true;
        }
    }

    function restore(text) {
        if (ready) return;
        let nextState = "writable";
        try {
            const parsed = JSON.parse(text);
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("object");
            document = parsed;
            if (parsed.version !== 1) {
                nextState = "unsupported";
            } else {
                const nextCounts = {}, nextVisits = {};
                for (const key of knownKeys) {
                    const count = parsed.counts && parsed.counts[key];
                    const visit = parsed.lastVisited && parsed.lastVisited[key];
                    if (typeof count === "number" && Number.isSafeInteger(count) && count > 0) nextCounts[key] = count;
                    if (typeof visit === "number" && Number.isSafeInteger(visit) && visit > 0) {
                        nextVisits[key] = visit;
                        sequence = Math.max(sequence, visit);
                    }
                }
                counts = nextCounts;
                lastVisited = nextVisits;
            }
        } catch (error) {
            nextState = "corrupt";
        }
        finishLoading(nextState);
    }

    function finishLoading(nextState) {
        state = nextState;
        ready = true;
        const pending = pendingVisits;
        pendingVisits = [];
        for (const key of pending) record(key);
    }

    function record(key) {
        if (knownKeys.indexOf(key) < 0) return;
        if (!ready) {
            pendingVisits = pendingVisits.concat([key]);
            return;
        }
        const nextCounts = Object.assign({}, counts);
        const nextVisits = Object.assign({}, lastVisited);
        nextCounts[key] = Math.min(Number.MAX_SAFE_INTEGER, (nextCounts[key] || 0) + 1);
        nextVisits[key] = ++sequence;
        counts = nextCounts;
        lastVisited = nextVisits;
        revision++;
        dirty = true;
        if (state === "writable") debounce.restart();
    }

    function recentKeys(limit) {
        return Object.keys(lastVisited)
            .filter(key => knownKeys.indexOf(key) >= 0 && counts[key] > 0)
            .sort((left, right) => lastVisited[right] - lastVisited[left])
            .slice(0, Math.max(0, limit));
    }

    function topKeys(limit) {
        const result = Object.keys(counts).filter(key => knownKeys.indexOf(key) >= 0 && counts[key] > 0);
        result.sort((left, right) => counts[right] - counts[left] || (lastVisited[right] || 0) - (lastVisited[left] || 0) || knownKeys.indexOf(left) - knownKeys.indexOf(right));
        return result.slice(0, Math.max(0, limit));
    }

    function flush(blocking) {
        debounce.stop();
        if (saving && blocking === true) file.waitForJob();
        if (!ready || state !== "writable" || !dirty || saving) return;
        if (writeFailed) {
            file.reload();
            file.waitForJob();
        }
        const next = Object.assign({}, document, {version: 1,
            counts: Object.assign({}, document.counts || {}, counts),
            lastVisited: Object.assign({}, document.lastVisited || {}, lastVisited)});
        document = next;
        const text = JSON.stringify(next, null, 2) + "\n";
        if (file.text() === text) {
            dirty = false;
            writeFailed = false;
            return;
        }
        savedRevision = revision;
        saving = true;
        writeFailed = false;
        file.blockWrites = blocking === true;
        file.setText(text);
    }

    // Best effort for normal teardown; SIGKILL cannot complete pending writes.
    Component.onDestruction: flush(true)
}
