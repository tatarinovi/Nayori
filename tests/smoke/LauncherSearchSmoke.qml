import QtQuick
import Quickshell
import "tokens"
import "surfaces/launcher"
import "services/launcher/SearchModel.js" as SearchModel

ShellRoot {
    Tokens { id: theme }

    Item {
        width: 640
        height: 48
        Launcher {
            id: launcher
            anchors.fill: parent
            tokens: theme
            embedded: true
        }
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            const rows = SearchModel.buildRows({
                query: "firefox",
                apps: [{id: "firefox", name: "Firefox", genericName: "Browser"}],
                files: [{kind: "folder", name: "firefox", path: "/tmp/firefox", directory: "~"}],
                webTerms: "firefox",
                webUrl: "https://www.google.com/search?q=firefox"
            })
            if (rows.length !== 3)
                throw new Error("rows " + rows.length)
            if (rows[0].kind !== "application" || rows[0].typeLabel !== "приложение" || rows[0].section !== "Приложения")
                throw new Error("app row")
            if (rows[1].kind !== "folder" || rows[1].typeLabel !== "папка" || rows[1].section !== "Файлы")
                throw new Error("folder row")
            if (rows[2].kind !== "web" || rows[2].typeLabel !== "интернет" || rows[2].section)
                throw new Error("web row")
            const command = SearchModel.buildRows({
                query: ">echo hi",
                apps: [{id: "echo", name: "Echo", genericName: ""}],
                files: [{kind: "file", name: "echo", path: "/tmp/echo", directory: "~"}],
                commandOk: true,
                commandArgv: ["echo", "hi"],
                webTerms: "echo",
                webUrl: "https://www.google.com/search?q=echo"
            })
            if (command.length !== 1 || command[0].kind !== "command" || command[0].distinct !== true)
                throw new Error("command mixed with files")
            const plan = SearchModel.activationPlan(command[0])
            if (plan.action !== "argv" || plan.argv.length !== 2 || plan.argv[0] !== "echo" || plan.argv[1] !== "hi")
                throw new Error("argv")
            const shell = SearchModel.activationPlan({kind: "command", ok: true, pending: false, argv: ["sh", "-c", "echo hi"]})
            if (shell.action !== "none")
                throw new Error("shell wrapper")
            const moved = SearchModel.move(rows, 0, 1)
            if (!moved.pinned || moved.index !== 1 || moved.key !== rows[1].key)
                throw new Error("move")
            const grown = [rows[0], {key: "file:/tmp/new", kind: "file"}, rows[1], rows[2]]
            const kept = SearchModel.reconcile(grown, moved.index, moved.key, true)
            if (kept.key !== rows[1].key || kept.index !== 2)
                throw new Error("selection jumped")
            if (SearchModel.resultIsCurrent(2, {generation: 1}))
                throw new Error("stale generation accepted")
            if (!SearchModel.resultIsCurrent(2, {generation: 2}))
                throw new Error("current generation dropped")
            if (SearchModel.webTerms(">ls") !== "" || SearchModel.isCommandQuery("notes") )
                throw new Error("command prefix")
            launcher.open()
            if (!launcher.opened || launcher.rows.length !== 0)
                throw new Error("open state")
            console.log("LAUNCHER_SEARCH_SMOKE_PASS")
            Qt.quit()
        }
    }
}
