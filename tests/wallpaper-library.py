import os, tempfile, subprocess, shutil, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
harness=root/f'.WallpaperLibrarySmoke-{os.getpid()}.qml'
source='''import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "tokens"
import "services/canvas"
import "surfaces/settings"
ShellRoot {
 id: test
 property int phase: 0
 property int colorWrites: 0
 Tokens { id: theme }
 Process {
  id: addImage
  command: ["cp", "--", decodeURIComponent(String(manager.defaultSource).replace(/^file:\\/\\//, "")), decodeURIComponent(String(page.libraryFolder).replace(/^file:\\/\\//, "")) + "/added.png"]
 }
 WallpaperManager { id: manager; storageDirectory: Quickshell.env("NAYORI_TEST_CONFIG") }
 FloatingWindow {
  visible: true; implicitWidth: 1000; implicitHeight: 900
  WallpaperPage { id: page; anchors.fill: parent; tokens: theme; manager: manager; accentMode: "manual"
   onAccentModeChangedRequested: mode => { test.colorWrites++; accentMode = mode }
   Component.onCompleted: if (Quickshell.env("NAYORI_TEST_RESTORE") !== "1") libraryFolder = Quickshell.env("NAYORI_TEST_FOLDER")
  }
  Test.TestEvent { id: input }
 }
 function find(item) {
  if (item.fileName === "a.png") return item
  for (const child of item.children || []) { const result = find(child); if (result) return result }
  return null
 }
 Timer {
  interval: 100; running: true; repeat: true
  onTriggered: {
   if (!manager.ready) return
   if (Quickshell.env("NAYORI_TEST_RESTORE") === "large") {
    if (test.phase === 0 && page.imageCount === 3000) { page.searchText = "wall-02999"; test.phase = 1 }
    else if (test.phase === 1 && page.imageCount === 1) { console.log("LIBRARY_PASS large/search"); Qt.quit() }
    return
   }
   if (test.phase === 17) {
    if (!page.canApply) return
    page.draftDynamic = true
    page.apply()
    if (test.colorWrites !== 1 || page.accentMode !== "automatic") { console.error("LIBRARY_FAIL automatic"); Qt.exit(1); return }
    test.phase = 18; return
   }
   if (test.phase === 18) {
    if (!page.canApply) return
    page.draftDynamic = false
    page.apply()
    if (test.colorWrites !== 2 || page.accentMode !== "default") { console.error("LIBRARY_FAIL disable automatic"); Qt.exit(1); return }
    addImage.running = true; test.phase = 16; return
   }
   if (test.phase === 16) {
    if (page.imageCount !== 3) return
    console.log("LIBRARY_PASS preview/cancel/close/search/missing/manual/watch"); Qt.quit(); return
   }
   if (test.phase === 10) {
    if (page.imageCount !== 1) return
    if (page.appliedSearch !== "B") return
    page.searchText = "not-present"
    test.phase = 11; return
   }
   if (test.phase === 11) {
    if (page.imageCount !== 0) return
    page.searchText = ""
    test.phase = 12; return
   }
   if (test.phase === 12) {
    if (page.imageCount !== 2) return
    page.desktopPreview = true
    page.draftMode = "fit"
    test.phase = 13; return
   }
   if (test.phase === 13) {
    if (!manager.previewing) return
    if (manager.wallpaper(page.output).mode !== "fill" || manager.displayWallpaper(page.output).mode !== "fit") { console.error("LIBRARY_FAIL preview"); Qt.exit(1); return }
    page.cancel()
    if (manager.previewing || page.draftMode !== "fill") { console.error("LIBRARY_FAIL cancel"); Qt.exit(1); return }
    page.desktopPreview = true
    page.draftMode = "center"
    test.phase = 14; return
   }
   if (test.phase === 14) {
    if (!manager.previewing) return
    page.visible = false
    if (manager.previewing) { console.error("LIBRARY_FAIL hide"); Qt.exit(1); return }
    page.visible = true
    page.draftSource = "file:///missing-nayori-wallpaper.png"
    test.phase = 15; return
   }
   if (test.phase === 15) {
    if (page.canApply) return
    page.apply()
    if (!manager.state.wallpaper.source.endsWith("/a.png") || test.colorWrites !== 0) { console.error("LIBRARY_FAIL missing/manual"); Qt.exit(1); return }
    page.draftSource = manager.wallpaper(page.output).source
    test.phase = 17; return
   }
   if (page.imageCount !== 2) return
   if (Quickshell.env("NAYORI_TEST_RESTORE") === "1") {
    if (decodeURIComponent(String(page.libraryFolder)) !== decodeURIComponent(Quickshell.env("NAYORI_TEST_FOLDER"))) { console.error("LIBRARY_FAIL restore", String(page.libraryFolder), Quickshell.env("NAYORI_TEST_FOLDER")); Qt.exit(1); return }
    console.log("LIBRARY_PASS restore"); Qt.quit(); return
   }
   if (test.phase === 0) {
    const item = test.find(page)
    if (!item) return
    item.forceActiveFocus()
    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
    if (!String(page.draftSource).endsWith("/a.png") || manager.state.wallpaper.source !== "") { console.error("LIBRARY_FAIL draft"); Qt.exit(1); return }
    test.phase = 1
   } else if (test.phase++ === 5) {
    page.apply()
   } else if (test.phase > 8 && !manager.saving) {
    if (!manager.state.wallpaper.source.endsWith("/a.png")) { console.error("LIBRARY_FAIL apply"); Qt.exit(1); return }
    page.searchText = "B"; test.phase = 10
   }
  }
 }
 Timer { interval: 15000; running: true; onTriggered: { console.error("LIBRARY_FAIL timeout", page.imageCount); Qt.exit(1) } }
}'''
try:
 harness.write_text(source)
 with tempfile.TemporaryDirectory(prefix='wallpaper-library-') as d:
  base=Path(d); images=base/'images with spaces'; images.mkdir(); config=base/'config';config.mkdir()
  for name in ['a.png','B.PNG']: shutil.copy(root/'assets/wallpapers/nayori.png', images/name)
  (images/'notes.txt').write_text('ignored')
  (images/'nested').mkdir()
  shutil.copy(root/'assets/wallpapers/nayori.png',images/'nested/hidden.png')
  large=base/'large'; large.mkdir()
  for index in range(3000): (large/f'wall-{index:05d}.png').symlink_to(root/'tests/fixtures/palette/red.png')
  for mode in ['0','1','large']:
   runtime=base/f'run{mode}';runtime.mkdir(mode=0o700)
   env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='basic',QT_QUICK_BACKEND='software',QS_DISABLE_FILE_WATCHER='1',XDG_RUNTIME_DIR=str(runtime),NAYORI_TEST_CONFIG=str(config),NAYORI_TEST_FOLDER=(large if mode=="large" else images).as_uri(),NAYORI_TEST_RESTORE=mode)
   result=subprocess.run(['qs','-p',str(harness),'--no-color'],env=env,capture_output=True,text=True,timeout=20)
   output=result.stdout+result.stderr
   assert result.returncode == 0 and 'LIBRARY_PASS' in output and not any(s in output for s in ['LIBRARY_FAIL','TypeError','ReferenceError','Binding loop','Unable to assign']), output
   if mode == '0': (images/'added.png').unlink(missing_ok=True)
   print('PASS', {'0':'gallery, search, preview, cancel, hide, missing file, folder watch', '1':'folder persists after restart', 'large':'3000 images, responsive filename search'}[mode])
  assert json.loads((config/'canvas.json').read_text())['wallpaper']['source'].endswith('/a.png')
finally: harness.unlink(missing_ok=True)
