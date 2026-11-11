.pragma library

// QML presentation dependencies resolve the same host without global state.
function find(item) {
    var node = item
    while (node) {
        if (node.widgetBridge !== undefined) return node.widgetBridge
        node = node.parent || null
    }
    return null
}
