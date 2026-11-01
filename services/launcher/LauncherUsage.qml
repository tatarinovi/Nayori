import QtQuick
import Quickshell
import Quickshell.Io

// Launcher-owned application launch history, independent from settings.json.
QtObject {
    id: root

    property string storageDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/nayori"
    property var counts: ({})
    property var lastVisited: ({})
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
        onExited: root.file.path = root.storageDirectory + "/launcher-usage.json"
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
                for (const key of Object.keys(parsed.counts || {})) {
                    if (!validKey(key)) continue;
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
        if (!validKey(key)) return;
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

    function validKey(key) {
        return typeof key === "string" && key.length > 0 && key.length <= 512
            && key !== "__proto__" && key !== "constructor" && key !== "prototype";
    }

    function topKeys(limit) {
        return Object.keys(counts).filter(key => validKey(key) && counts[key] > 0)
            .sort((left, right) => counts[right] - counts[left]
                || (lastVisited[right] || 0) - (lastVisited[left] || 0)
                || left.localeCompare(right))
            .slice(0, Math.max(0, limit));
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
