pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire as QsPw

QtObject {
    id: root

    readonly property bool ready: QsPw.Pipewire.ready
    readonly property var nodes: QsPw.Pipewire.nodes
    readonly property var defaultSink: QsPw.Pipewire.defaultAudioSink
    readonly property var defaultSource: QsPw.Pipewire.defaultAudioSource
    property int outputCount: 0
    property int inputCount: 0

    function isOutput(node): bool {
        return !!(node && node.audio && node.isSink && !node.isStream)
    }

    function isInput(node): bool {
        return !!(node && node.audio && !node.isSink && !node.isStream)
    }

    function recount() {
        let outputs = 0
        let inputs = 0
        const model = nodes
        const count = model && model.count !== undefined ? model.count : 0
        for (let i = 0; i < count; i++) {
            const node = model.objectAt(i)
            if (isOutput(node))
                outputs++
            else if (isInput(node))
                inputs++
        }
        outputCount = outputs
        inputCount = inputs
    }

    function setVolume(node, value): bool {
        if (!node || !node.audio || !isFinite(value))
            return false
        node.audio.volume = Math.max(0, Math.min(1, value))
        return true
    }

    function setMuted(node, muted): bool {
        if (!node || !node.audio)
            return false
        node.audio.muted = !!muted
        return true
    }

    function preferSink(node): bool {
        if (!isOutput(node))
            return false
        QsPw.Pipewire.preferredDefaultAudioSink = node
        return true
    }

    function preferSource(node): bool {
        if (!isInput(node))
            return false
        QsPw.Pipewire.preferredDefaultAudioSource = node
        return true
    }

    property Instantiator census: Instantiator {
        model: QsPw.Pipewire.nodes
        delegate: QtObject {
            required property var modelData
            Component.onCompleted: root.recount()
            Component.onDestruction: root.recount()
        }
        onObjectAdded: root.recount()
        onObjectRemoved: root.recount()
    }

    Component.onCompleted: recount()
}
