pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "surfaces/island"
import "surfaces/settings"
import "surfaces/capture"

ShellRoot {
    id: root
    Tokens { id: theme }
    AttachmentMotion { id: motion; tokens: theme }
    QtObject {
        id: fakePlayer
        property bool isPlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        property bool lengthSupported: true
        property bool positionSupported: true
        property real length: 100
        property int toggles: 0
        function previous() {}
        function next() {}
        function togglePlaying() { isPlaying = !isPlaying; toggles++ }
    }
    QtObject {
        id: recording
        property bool controlsVisible: true
        property bool paused: false
        property string state: "recording"
        property string timeText: "00:12"
        function pause() {}
        function stop() {}
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1100
        implicitHeight: 680
        color: theme.color.background
        Item {
            id: scene
            anchors.fill: parent
            MorphingIsland {
                id: island
                tokens: theme
                testMode: true
                attachment: motion.progress
                y: motion.topOffset
                anchors.horizontalCenter: parent.horizontalCenter
            }
            CompactMediaControls {
                id: media
                tokens: theme
                attachment: motion.progress
                player: fakePlayer
                position: 45
                showing: true
                anchors.top: island.top
                anchors.left: island.right
                anchors.leftMargin: motion.gap
            }
            CompactClock {
                id: clock
                tokens: theme
                attachment: motion.progress
                showing: true
                active: false
                anchors.top: island.top
                anchors.right: island.left
                anchors.rightMargin: motion.gap
            }
            CaptureCapsule {
                id: capture
                tokens: theme
                attachment: motion.progress
                service: recording
                y: 0
                x: 16
                visible: false
            }
            IslandPage {
                id: settingsPage
                tokens: theme
                visible: false
                width: 480
                islandPlacement: motion.attached ? "attached" : "floating"
                onIslandPlacementChangedRequested: placement => motion.attached = placement === "attached"
            }
        }
        AttachedRegion { id: mediaRegion; surface: media }
        TestCase {
            id: checks
            when: false
            function run() {
                const contour = findChild(island, "attachedContour")
                const selector = findChild(settingsPage, "islandPlacementSelector")
                compare(motion.progress, 0)
                compare(island.y, 8)
                verify(!contour.visible)
                selector.activated("attached")
                wait(110)
                verify(motion.progress > 0 && motion.progress < 1)
                compare(media.attachment, island.attachment)
                compare(clock.attachment, island.attachment)
                // Interrupt a running morph; the next target starts at its
                // current value rather than flashing the other surface.
                const before = motion.progress
                motion.attached = false
                verify(Math.abs(motion.progress - before) < 0.05)
                wait(35)
                motion.attached = true
                wait(330)
                compare(motion.progress, 1)
                compare(island.y, 0)
                compare(media.y, 0)
                verify(contour.visible && contour.topStart < 0)
                const beat = findChild(island, "attachedBeatStroke")
                compare(contour.topY + contour.strokeWidth / 2, 0)
                compare(beat.topY + beat.strokeWidth / 2, 0)
                compare(beat.topY + beat.topDepth, contour.topY + contour.topDepth)
                compare(beat.inset - beat.strokeWidth / 2, 0)
                compare(beat.shoulderStartX, contour.shoulderStartX)
                compare(contour.shoulderStartX, -island.shoulder)
                verify(media.x - media.shoulder >= island.x + island.width + island.shoulder)
                compare(contour.strokeColor, theme.color.border)
                compare(capture.attachment, 1)
                theme.accentDerived = true
                theme.accentSource = "#85b9a4"
                compare(findChild(media, "compactMediaProgress").ink, Qt.alpha(theme.color.accent, 0.8))
                findChild(media, "compactMedia_toggle").clicked()
                compare(fakePlayer.toggles, 1)
                verify(!fakePlayer.isPlaying)
                findChild(media, "compactMedia_toggle").clicked()
                verify(fakePlayer.isPlaying)
                island.expanded = true
                wait(330)
                island.currentPage = 3
                wait(280)
                compare(island.height, 630)
                compare(island.y, 0)
                verify(contour.topStart < 0)
                // State and mode changes at the same time must settle.
                for (let i = 0; i < 6; ++i) {
                    island.expanded = i % 2 === 0
                    motion.attached = i % 2 === 1
                    wait(25)
                }
                island.expanded = false
                motion.attached = true
                wait(350)
                compare(island.progress, 0)
                compare(island.height, 48)
                compare(motion.progress, 1)
                media.showing = false
                wait(70)
                verify(media.visible && media.reveal > 0 && media.reveal < 1)
                verify(!media.enabled)
                wait(240)
                verify(!media.visible)
                compare(mediaRegion.width, 0)
                theme.animationsEnabled = false
                motion.attached = false
                compare(motion.progress, 0)
                motion.attached = true
                compare(motion.progress, 1)
                island.availableWidth = 240
                island.expanded = true
                compare(island.width, 240)
                island.launcherOpen = true
                const launcher = findChild(island, "islandLauncherLoader").item
                compare(launcher.embeddedChromeOpacity, 0)
                compare(findChild(launcher, "embeddedLauncherRing").opacity, 0)
                compare(findChild(launcher, "embeddedLauncherFill").opacity, 0)
                compare(island.color, theme.color.background)
                motion.attached = false
                compare(launcher.embeddedChromeOpacity, 1)
                compare(findChild(launcher, "embeddedLauncherRing").opacity, 1)
                motion.attached = true
                compare(island.width, 240)
                compare(island.y, 0)
                island.launcherOpen = false
                island.expanded = false
                verify(island.width <= 240)
                console.log("ATTACHED_ISLAND_PASS")
                Qt.quit()
            }
        }
        Timer { interval: 200; running: true; onTriggered: checks.run() }
    }
}
