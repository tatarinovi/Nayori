import os, tempfile, subprocess, shutil, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
harness=root/'.WallpaperLibrarySmoke.qml'
source='''import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "services/canvas"
import "surfaces/settings"
ShellRoot {
 id: test
 property int phase: 0
 Tokens { id: theme }
 WallpaperManager { id: manager; storageDirectory: Quickshell.env("NAYORI_TEST_CONFIG") }
 FloatingWindow {
  visible: true; implicitWidth: 1000; implicitHeight: 900
  WallpaperPage { id: page; anchors.fill: parent; tokens: theme; manager: manager
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
   if (!manager.ready || page.imageCount !== 2) return
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
    manager.apply(page.output, String(page.draftSource), page.draftMode, true, true)
   } else if (test.phase > 8 && !manager.saving) {
    if (!manager.state.wallpaper.source.endsWith("/a.png")) { console.error("LIBRARY_FAIL apply"); Qt.exit(1); return }
    console.log("LIBRARY_PASS select/apply"); Qt.quit()
   }
  }
 }
 Timer { interval: 8000; running: true; onTriggered: { console.error("LIBRARY_FAIL timeout", page.imageCount); Qt.exit(1) } }
}'''
try:
 harness.write_text(source)
 with tempfile.TemporaryDirectory(prefix='wallpaper-library-') as d:
  base=Path(d); images=base/'images with spaces'; images.mkdir(); config=base/'config';config.mkdir()
  for name in ['a.png','B.PNG']: shutil.copy(root/'assets/wallpapers/nayori.png', images/name)
  (images/'notes.txt').write_text('ignored')
  (images/'nested').mkdir()
  shutil.copy(root/'assets/wallpapers/nayori.png',images/'nested/hidden.png')
  for mode in ['0','1']:
   runtime=base/f'run{mode}';runtime.mkdir(mode=0o700)
   env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='basic',QT_QUICK_BACKEND='software',QS_DISABLE_FILE_WATCHER='1',XDG_RUNTIME_DIR=str(runtime),NAYORI_TEST_CONFIG=str(config),NAYORI_TEST_FOLDER=images.as_uri(),NAYORI_TEST_RESTORE=mode)
   result=subprocess.run(['qs','-p',str(harness),'--no-color'],env=env,capture_output=True,text=True,timeout=12)
   output=result.stdout+result.stderr
   assert result.returncode == 0 and 'LIBRARY_PASS' in output and not any(s in output for s in ['LIBRARY_FAIL','TypeError','ReferenceError','Binding loop','Unable to assign']), output
   print('PASS', 'folder filtering, selection draft, apply' if mode=='0' else 'folder persists after restart')
  assert json.loads((config/'canvas.json').read_text())['wallpaper']['source'].endswith('/a.png')
finally: harness.unlink(missing_ok=True)
