import QtQuick
Item {
    property string source: ""
    property string artUrl: ""
    property string sourceUrl: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string identity: ""
    property bool active: true
    readonly property string displaySource: active ? sourceUrl || source || artUrl : ""
}
