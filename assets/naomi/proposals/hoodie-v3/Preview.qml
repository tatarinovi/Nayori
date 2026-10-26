import QtQuick
import Quickshell
import "Sprite.js" as Art

// Static approval proof. Deliberately separate from the desktop appearance picker.
ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 280
        implicitHeight: 400
        color: "transparent"
        Rectangle {
            id: scene
            anchors.fill: parent
            color: "#242229"
            Canvas {
                anchors.fill: parent
                smooth: false
                antialiasing: false
                onPaint: {
                    const ctx=getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0,0,width,height)
                    for(const run of Art.runs) {
                        ctx.fillStyle=Art.palette[run[3]]
                        ctx.fillRect(run[0]*2,run[1]*2,run[2]*2,2)
                    }
                }
            }
        }
        Timer {
            interval: 500
            running: true
            onTriggered: scene.grabToImage(result => {
                const path=Quickshell.env("NAYORI_PROPOSAL_OUTPUT") || "/tmp/naomi-v3-qml.png"
                if (!result.saveToFile(path)) {
                    console.error("NAOMI_PROPOSAL_FAIL save")
                    Qt.exit(1)
                    return
                }
                console.log("NAOMI_PROPOSAL_PASS 280x400 indexed Canvas")
                Qt.quit()
            })
        }
    }
}
