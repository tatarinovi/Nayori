import QtQuick
import Quickshell
import "services/desktop"

ShellRoot {
    id: root
    function check(value, message) {
        if (!value) { console.error("WIDGET_RUNTIME_FAIL", message); Qt.exit(1) }
    }
    QtObject {
        id: store
        property bool ready: true
        property var values: ({desktopWidgets:{}})
        property int writes: 0
        function update(changes) { values = Object.assign({}, values, changes); writes++ }
    }
    ImportedWidgetRuntime {
        id: runtime
        settings: store
        testMode: true
    }
    Component.onCompleted: {
        runtime.request("github", {user:"first"}, "one")
        const oldToken = runtime.requests.one.token
        runtime.request("github", {user:"second"}, "one")
        const newToken = runtime.requests.one.token
        check(newToken !== oldToken, "changed input gets a new generation")
        runtime.accept("one", {total:99}, oldToken)
        check(runtime.results.one === undefined && runtime.requests.one.token === newToken, "stale reply cannot overwrite new input")
        runtime.accept("one", {total:7}, newToken)
        check(runtime.results.one.total === 7 && runtime.requests.one === undefined, "current reply accepted")
        runtime.request("zones", {zones:["UTC"]}, "removed:zones")
        const removedToken = runtime.requests["removed:zones"].token
        runtime.release("removed:")
        runtime.accept("removed:zones", {entries:[1]}, removedToken)
        check(runtime.results["removed:zones"] === undefined, "deleted instance ignores late replies")
        runtime.request("capabilities", {}, "caps")
        runtime.accept("caps", {brightness:false,nightlight:false}, runtime.requests.caps.token)
        check(runtime.capabilities.brightness === false, "missing optional tools remain unavailable")
        const now = Date.now()
        store.update({desktopWidgets:{"DP-1":{snap:true,items:[
            {id:"one",type:"shima_timers",options:{countdownSeconds:10,timerState:{countdown:{running:true,elapsed:0,startedAt:now-11000}}}},
            {id:"two",type:"shima_timers",options:{focusMinutes:1,breakMinutes:1,timerState:{focus:{running:true,elapsed:0,startedAt:now-61000}}}},
            {id:"other",type:"shima_notes",options:{text:"preserve",unknown:42}}
        ]}}})
        runtime.advanceTimers(now)
        const items = store.values.desktopWidgets["DP-1"].items
        check(!items[0].options.timerState.countdown.running && items[0].options.timerState.countdown.elapsed === 10, "countdown completes and persists")
        check(items[1].options.timerState.focus.isBreak && items[1].options.timerState.focus.running, "focus advances to a running break")
        check(items[2].options.unknown === 42, "timer update preserves unrelated options")
        const writes = store.writes
        runtime.advanceTimers(now)
        check(store.writes === writes, "phase is advanced once")
        // Test mode records actions, never sends power/session commands.
        let action = ""
        runtime.actionRequested.connect(name => { action = name })
        runtime.action("poweroff")
        check(action === "poweroff", "original action is routed to host")
        console.log("WIDGET_RUNTIME_PASS")
        Qt.quit()
    }
}
