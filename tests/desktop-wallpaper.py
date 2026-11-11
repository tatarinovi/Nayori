"""Exercise the desktop drawer and its shared collection without Wayland."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
harness = root / f'.DesktopWallpaperSmoke-{os.getpid()}.qml'
source = '''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens"
import "services/canvas"
import "surfaces/settings"
import "surfaces/desktop"
ShellRoot {
 id: test
 property int phase: 0
 property string before: ""
 function check(ok, message) { if (!ok) throw new Error(message) }
 function find(item, name) {
  if (!item) return null
  if (item.objectName === name) return item
  for (const child of item.children || []) { const result = find(child, name); if (result) return result }
  return null
 }
 Tokens { id: theme; animationsEnabled: false }
 WallpaperManager { id: manager; storageDirectory: Quickshell.env("NAYORI_TEST_CONFIG") }
 FloatingWindow {
  visible: false
  WallpaperPage { id: settings; tokens: theme; manager: manager }
 }
 FloatingWindow {
  id: window
  visible: true; implicitWidth: 360; implicitHeight: 720
  Loader {
   id: drawer
   anchors.fill: parent
   active: false
   sourceComponent: DesktopWallpaperPicker { tokens: theme; manager: manager; output: "DP-1" }
  }
 }
 Timer {
  interval: 100; running: true; repeat: true
  onTriggered: {
   if (!manager.ready || manager.saving) return
   try {
    if (test.phase === 0) {
     drawer.active = true
     test.phase = 1; return
    }
    const picker = test.find(window.contentItem, "desktop-wallpaper-picker")
    if (test.phase === 1) {
     if (!picker || picker.imageCount !== 1) return
     test.check(picker.compact && !picker.draftShared, "embedded drawer")
     test.check(String(picker.libraryFolder) === String(settings.libraryFolder), "same initial folder")
     settings.libraryFolder = Quickshell.env("NAYORI_TEST_SECOND")
     test.phase = 2; return
    }
    if (test.phase === 2) {
     if (!picker || String(picker.libraryFolder) !== Quickshell.env("NAYORI_TEST_SECOND") || picker.imageCount !== 2) return
     test.check(String(manager.libraryFolder) === String(settings.libraryFolder), "folder sync from settings")
     test.before = JSON.stringify(manager.state)
     picker.draftSource = Quickshell.env("NAYORI_TEST_SECOND") + "/second.png"
     // Offscreen Qt's unnamed output cannot be persisted as an independent target.
     picker.draftShared = true
     test.phase = 3; return
    }
    if (test.phase === 3) {
     if (!manager.previewing || !picker.canApply) return
     test.check(JSON.stringify(manager.state) === test.before, "preview did not save")
     test.check(manager.displayWallpaper("DP-1").source.endsWith("/second.png"), "editor previews draft")
     const cancel = test.find(window.contentItem, "desktop-wallpaper-cancel")
     cancel.clicked()
     test.check(!manager.previewing && JSON.stringify(manager.state) === test.before, "cancel restored")
     picker.chooseSource(Quickshell.env("NAYORI_TEST_SECOND") + "/second.png")
     picker.draftShared = true
     test.phase = 4; return
    }
    if (test.phase === 4) {
     if (!picker.canApply || !manager.previewing) return
     test.find(window.contentItem, "desktop-wallpaper-apply").clicked()
     test.phase = 5; return
    }
    if (test.phase === 5) {
     test.check(manager.wallpaper("").source.endsWith("/second.png"), "apply saved selection")
     picker.libraryFolder = Quickshell.env("NAYORI_TEST_FIRST")
     test.phase = 8; return
    }
    if (test.phase === 8) {
     if (String(settings.libraryFolder) !== Quickshell.env("NAYORI_TEST_FIRST")) return
     test.check(String(manager.libraryFolder) === String(picker.libraryFolder), "folder sync from editor")
     picker.libraryFolder = Quickshell.env("NAYORI_TEST_SECOND")
     test.phase = 9; return
    }
    if (test.phase === 9) {
     if (String(settings.libraryFolder) !== Quickshell.env("NAYORI_TEST_SECOND")) return
     picker.chooseSource(Quickshell.env("NAYORI_TEST_SECOND") + "/third.png")
     test.phase = 6; return
    }
    if (test.phase === 6) {
     if (!manager.previewing) return
     drawer.active = false
     test.phase = 7; return
    }
    if (test.phase === 7) {
     test.check(!manager.previewing && !drawer.active, "leaving tab cancels only preview")
     console.log("DESKTOP_WALLPAPER_PASS shared-folder/live-sync/preview/cancel/apply/tab-close"); Qt.quit()
    }
   } catch (error) { console.error("DESKTOP_WALLPAPER_FAIL", error); Qt.exit(1) }
  }
 }
 Timer { interval: 12000; running: true; onTriggered: { console.error("DESKTOP_WALLPAPER_FAIL timeout", test.phase); Qt.exit(1) } }
}'''
try:
    harness.write_text(source)
    with tempfile.TemporaryDirectory(prefix='nayori-desktop-wallpaper-') as directory:
        base = Path(directory)
        config = base / 'config'
        config.mkdir()
        first = base / 'first'
        first.mkdir()
        second = base / 'second'
        second.mkdir()
        (first / 'first.png').symlink_to(root / 'tests/fixtures/palette/red.png')
        for name in ('second.png', 'third.png'):
            (second / name).symlink_to(root / 'tests/fixtures/palette/blue.png')
        initial = dict(version=1, enabled=True, shared=True, wallpaper=dict(source='', mode='fill'),
                       outputs={}, libraryFolder=first.as_uri())
        (config / 'canvas.json').write_text(json.dumps(initial))
        runtime = base / 'runtime'
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='basic',
                   QT_QUICK_BACKEND='software', QS_DISABLE_FILE_WATCHER='1',
                   XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(config),
                   NAYORI_TEST_CONFIG=str(config), NAYORI_TEST_FIRST=first.as_uri(), NAYORI_TEST_SECOND=second.as_uri())
        for key in ('WAYLAND_DISPLAY', 'DISPLAY', 'NIRI_SOCKET'):
            env.pop(key, None)
        result = subprocess.run(['qs', '-p', str(harness), '--no-color'], env=env,
                                capture_output=True, text=True, timeout=16)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'DESKTOP_WALLPAPER_PASS' in output and not any(
            word in output for word in ('DESKTOP_WALLPAPER_FAIL', 'TypeError', 'ReferenceError', 'Unable to assign', 'Binding loop')
        ), output
        saved = json.loads((config / 'canvas.json').read_text())
        assert saved['wallpaper']['source'].endswith('/second.png')
        assert saved['libraryFolder'] == second.as_uri()
        print('PASS desktop wallpaper drawer, live folder sync, preview, cancel, apply and tab cleanup')
finally:
    harness.unlink(missing_ok=True)
