"""Offscreen preview transaction: no compositor, live configuration or palette writers."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
harness = root / f'.WallpaperPreviewSmoke-{os.getpid()}.qml'
source = '''import QtQuick
import Quickshell
import "services/canvas"
ShellRoot {
 id: test
 property int phase: 0
 function check(ok, message) { if (!ok) throw new Error(message) }
 WallpaperManager { id: manager; storageDirectory: Quickshell.env("NAYORI_TEST_CONFIG") }
 Timer {
  interval: 80; running: true; repeat: true
  onTriggered: {
   if (!manager.ready || manager.saving) return
   try {
    if (test.phase === 0) {
     const before = JSON.stringify(manager.state)
     const disk = manager.file.text()
     const enabledState = JSON.parse(JSON.stringify(manager.state))
     enabledState.enabled = false
     manager.state = enabledState
     manager.preview("DP-1", String(manager.defaultSource), "center", false)
     test.check(manager.displayEnabled("DP-1") && !manager.displayEnabled("DP-2") && !manager.enabled, "disabled preview isolation")
     manager.cancelPreview()
     enabledState.enabled = true
     manager.state = JSON.parse(JSON.stringify(enabledState))
     manager.preview("DP-1", String(manager.defaultSource), "center", false)
     test.check(manager.displayWallpaper("DP-1").mode === "center", "target paint")
     test.check(manager.wallpaper("DP-1").mode === "fit", "committed source for palette")
     test.check(manager.displayWallpaper("DP-2").mode === "stretch", "other output")
     manager.preview("DP-2", String(manager.defaultSource), "fill", false)
     test.check(manager.displayWallpaper("DP-1").mode === "fit", "previous target restored")
     manager.preview("", String(manager.defaultSource), "center", true)
     test.check(manager.displayWallpaper("temporarily-absent").mode === "center", "all targets")
     manager.cancelPreview()
     test.check(manager.displayWallpaper("temporarily-absent").mode === "fit", "offline assignment restored")
     test.check(before === JSON.stringify(manager.state) && disk === manager.file.text() && !manager.saving, "preview wrote state")
     manager.preview("DP-1", "https://example.com/image.png", "fill", false)
     test.check(!manager.previewing, "remote preview rejected")
     manager.preview("DP-1", String(manager.defaultSource), "invalid", false)
     test.check(!manager.previewing, "invalid mode rejected")
     manager.preview("DP-1", String(manager.defaultSource), "center", false)
     manager.apply("DP-2", String(manager.defaultSource), "fill", false, true)
     test.check(!manager.previewing, "commit supersedes preview")
     test.phase = 1
    } else if (test.phase === 1) {
     test.check(manager.message === "Обои сохранены.", "save completed")
     manager.apply("DP-2", String(manager.defaultSource), "fill", false, true)
     test.check(!manager.saving && manager.message === "Обои сохранены.", "identical apply must not await saved signal")
     manager.setLibraryFolder("file:///tmp/nayori-wallpaper-test-collection")
     test.phase = 2
    } else {
     manager.setLibraryFolder("file:///tmp/nayori-wallpaper-test-collection")
     test.check(!manager.saving && manager.message === "Обои сохранены.", "identical folder save must not await saved signal")
     console.log("PREVIEW_PASS targets/cancel/no-write/invalid/commit"); Qt.quit()
    }
   } catch (error) { console.error("PREVIEW_FAIL", error); Qt.exit(1) }
  }
 }
 Timer { interval: 8000; running: true; onTriggered: Qt.exit(1) }
}'''
try:
    harness.write_text(source)
    with tempfile.TemporaryDirectory(prefix='nayori-preview-') as directory:
        base = Path(directory)
        config = base / 'config'
        config.mkdir()
        runtime = base / 'run'
        runtime.mkdir(mode=0o700)
        wallpaper = {'source': '', 'mode': 'fit', 'futureWallpaperKey': 42}
        initial = {
            'version': 1, 'enabled': True, 'shared': False,
            'wallpaper': wallpaper,
            'outputs': {
                'DP-1': dict(wallpaper),
                'DP-2': {'source': '', 'mode': 'stretch', 'futureOutputKey': 73},
                'temporarily-absent': dict(wallpaper),
            },
            'futureRootKey': {'keep': True},
        }
        (config / 'canvas.json').write_text(json.dumps(initial))
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='basic',
                   QT_QUICK_BACKEND='software', QS_DISABLE_FILE_WATCHER='1',
                   XDG_RUNTIME_DIR=str(runtime), NAYORI_TEST_CONFIG=str(config))
        for name in ('WAYLAND_DISPLAY', 'DISPLAY', 'NIRI_SOCKET'):
            env.pop(name, None)
        result = subprocess.run(['qs', '-p', str(harness), '--no-color'], env=env,
                                capture_output=True, text=True, timeout=12)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'PREVIEW_PASS' in output and not any(
            word in output for word in ('PREVIEW_FAIL', 'ReferenceError', 'TypeError', 'Unable to assign')
        ), output
        saved = json.loads((config / 'canvas.json').read_text())
        assert saved['outputs']['DP-1'] == initial['outputs']['DP-1']
        assert saved['outputs']['temporarily-absent'] == initial['outputs']['temporarily-absent']
        assert saved['outputs']['DP-2']['mode'] == 'fill'
        assert saved['outputs']['DP-2']['futureOutputKey'] == 73
        assert saved['futureRootKey'] == initial['futureRootKey']
        print('PASS preview transaction, target replacement, cancellation, invalid input, unknown keys, offline outputs')
finally:
    harness.unlink(missing_ok=True)
