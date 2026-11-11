pragma ComponentBehavior: Bound
import QtQuick
import "../settings"
import "../../services/visualizer/VisualizerConfig.js" as Config

Column {
    id: root
    required property var tokens
    required property var spec
    required property var item
    signal edited(string key, var value)
    spacing: 2
    SettingsLabel {
        width: parent.width
        tokens: root.tokens
        text: root.spec.label + (root.spec.type === "number" ? "  " + Number(root.item[root.spec.key]).toFixed(2) : "")
    }
    Loader {
        width: parent.width
        sourceComponent: root.spec.type === "bool" ? toggle : root.spec.type === "choice" ? choices : slider
    }
    Component {
        id: slider
        SettingsSlider {
            tokens: root.tokens
            label: root.spec.label
            source: root.item[root.spec.key]
            from: (Config.ranges[root.spec.key] || [0,1])[0]
            to: (Config.ranges[root.spec.key] || [0,1])[1]
            stepSize: ["bars", "segments"].indexOf(root.spec.key) >= 0 ? 1 : 0
            onChanged: value => root.edited(root.spec.key, value)
        }
    }
    Component {
        id: toggle
        SettingsSwitch {
            tokens: root.tokens
            text: root.spec.label
            checked: root.item[root.spec.key]
            onToggled: root.edited(root.spec.key, checked)
        }
    }
    Component {
        id: choices
        Flow {
            spacing: 4
            Repeater {
                model: Config.choices[root.spec.key] || []
                delegate: SettingsButton {
                    required property string modelData
                    tokens: root.tokens
                    text: modelData
                    primary: root.item[root.spec.key] === modelData
                    onClicked: root.edited(root.spec.key, modelData)
                }
            }
        }
    }
}
