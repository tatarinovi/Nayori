#!/usr/bin/env python3
"""All writes use disposable HOME/XDG; no live commands are executed."""
import importlib.util
import os
from pathlib import Path
import sys
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services/system"))
spec = importlib.util.spec_from_file_location("cursor_theme", ROOT / "services/system/cursor_theme.py")
cursor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cursor)


class CursorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = patch.dict(os.environ, {
            "HOME": str(self.home), "XDG_CONFIG_HOME": str(self.home / "config"),
            "XDG_DATA_HOME": str(self.home / "data"), "XDG_DATA_DIRS": str(self.home / "system"),
            "NIRI_CONFIG": str(self.home / "config/niri/config.kdl"),
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        self.config = cursor.niri.niri_config_path()
        self.config.parent.mkdir(parents=True)
        self.config.write_text('include "input.kdl"\ninput {\n    mouse { accel-speed 0; }\n}\n')
        self.included = self.config.parent / "input.kdl"
        self.included.write_text('cursor { hide-when-typing; xcursor-theme "old"; }\n')
        (self.home / "data/icons/Test/cursors").mkdir(parents=True)
        self.gtk = self.home / "config/gtk-3.0/settings.ini"
        self.gtk.parent.mkdir()
        self.gtk.write_text('[Settings]\n# keep\ngtk-theme-name=Custom\ngtk-cursor-theme-name=old\n')

    def test_apply_preserves_and_is_idempotent(self):
        with patch.object(cursor, "command", side_effect=AssertionError("live command")):
            result = cursor.apply("Test", 32, validator=lambda path: True)
            self.assertTrue(result["ok"])
            self.assertEqual(result["theme"], "Test")
            self.assertEqual(result["size"], 32)
            self.assertIn("hide-when-typing", self.included.read_text())
            self.assertIn("# keep\ngtk-theme-name=Custom", self.gtk.read_text())
            self.assertNotIn("cursor {", self.config.read_text())
            self.assertEqual(cursor.apply("Test", 32, validator=lambda path: True)["backups"], [])

    def test_failed_validation_restores_everything(self):
        original = self.gtk.read_bytes(), self.included.read_bytes()
        with self.assertRaises(cursor.niri.ApplyError):
            cursor.apply("Test", 32, validator=lambda path: False)
        self.assertEqual((self.gtk.read_bytes(), self.included.read_bytes()), original)
        self.assertFalse((self.home / "config/environment.d/90-nayori-cursor.conf").exists())
        self.assertFalse((self.home / ".Xresources").exists())

    def test_invalid_and_missing_theme_do_not_write(self):
        for theme, size in [("missing", 24), ("../Test", 24), ("Test", None), ("Test", True), ("Test", 0)]:
            with self.assertRaises(cursor.niri.ApplyError):
                cursor.apply(theme, size, validator=lambda path: True)
        self.assertNotIn("gtk-cursor-theme-size", self.gtk.read_text())

    def test_duplicate_cursor_rejected(self):
        self.config.write_text(self.config.read_text() + 'cursor {}\n')
        with self.assertRaises(cursor.niri.ApplyError):
            cursor.apply("Test", 24, validator=lambda path: True)

    def test_symlink_is_not_followed(self):
        target = self.home / "original"
        target.write_text("keep")
        (self.home / ".Xresources").symlink_to(target)
        with self.assertRaises(cursor.niri.ApplyError):
            cursor.apply("Test", 24, validator=lambda path: True)
        self.assertEqual(target.read_text(), "keep")

    def test_real_niri_validation(self):
        if not cursor.niri.niri_binary():
            self.skipTest("niri unavailable")
        self.assertTrue(cursor.apply("Test", 24)["ok"])

    def test_preview_decodes_real_pixels_and_rejects_damage(self):
        path = self.home / "data/icons/Test/cursors/left_ptr"
        kind = 0xfffd0002
        path.write_bytes(b"Xcur" + struct.pack("<3I", 16, 1, 1)
                         + struct.pack("<3I", kind, 24, 28)
                         + struct.pack("<9I", 36, kind, 24, 1, 1, 1, 0, 0, 0)
                         + bytes([10, 20, 30, 255]))
        preview = cursor.themes()[0]["previews"][0]
        self.assertEqual(preview["size"], 24)
        png = cursor.base64.b64decode(preview["source"].split(",", 1)[1])
        start = png.index(b"IDAT") + 4
        length = struct.unpack_from(">I", png, start - 8)[0]
        self.assertEqual(cursor.zlib.decompress(png[start:start + length]), bytes([0, 30, 20, 10, 255]))
        path.write_bytes(path.read_bytes()[:-2])
        self.assertEqual(cursor.cursor_previews(path), [])
        path.write_bytes(b"broken")
        self.assertEqual(cursor.cursor_previews(path), [])


if __name__ == "__main__":
    unittest.main()
