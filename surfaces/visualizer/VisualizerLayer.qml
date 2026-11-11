pragma ComponentBehavior: Bound
import QtQuick
import "vendor"

Item {
    id: root
    required property var service
    required property var tokens
    required property string output
    property var sourceAudio: null
    property color paletteAccent: tokens.color.accent
    property bool editing: false
    readonly property string roster: JSON.stringify(service ? service.onOutput(output).filter(v => v.enabled).map(v => v.id) : [])
    readonly property var instances: JSON.parse(roster)
    readonly property string consumerKey: "visualizers-" + String(root)
    readonly property bool wantsAudio: visible && instances.length > 0 && !tokens.motion.off
    property var subscribedAudio: null
    function subscribe() {
        if (subscribedAudio && subscribedAudio !== sourceAudio) subscribedAudio.systemConsumer(consumerKey, false)
        subscribedAudio = sourceAudio
        if (subscribedAudio) subscribedAudio.systemConsumer(consumerKey, wantsAudio)
    }
    onWantsAudioChanged: subscribe()
    onSourceAudioChanged: subscribe()
    Component.onCompleted: subscribe()
    Component.onDestruction: if (subscribedAudio) subscribedAudio.systemConsumer(consumerKey, false)
    Repeater {
        model: root.instances
        delegate: Item {
            id: instance
            required property string modelData
            readonly property var instanceData: root.service.items.find(v => v.id === modelData) || {}
            required property int index
            anchors.fill: parent
            VizItem { id: vizCfg; data: instance.instanceData }
            VisualizerView {
                anchors.fill: parent
                cfg: vizCfg
                instanceId: instance.modelData
                index: instance.index
                tokens: root.tokens
                paletteAccent: root.paletteAccent
                sourceAudio: root.sourceAudio
                frameRate: root.service.config.fps
                adaptive: root.service.config.adaptive
            }
            VisualizerHandles {
                anchors.fill: parent
                visible: root.editing
                cfg: vizCfg
                service: root.service
                tokens: root.tokens
            }
        }
    }
}
