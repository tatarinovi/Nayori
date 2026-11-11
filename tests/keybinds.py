#!/usr/bin/env python3
"""Disposable keybind regression fixtures; never read or reload the live session."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services/keybinds"))
import keybinds as kb


class KeybindTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nayori-keybinds-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.path = self.base / "niri/config.kdl"
        self.path.parent.mkdir()
        (self.path.parent / "cfg").mkdir()
        self.child = self.path.parent / "cfg/binds.kdl"
        self.path.write_text('// root unchanged\ninclude "cfg/binds.kdl"\nlayout { gaps 8; }\n')
        self.child.write_text('''// user comment
binds {
    /* outer /* nested */ comment */
    "Mod+Return" repeat=false hotkey-overlay-title="Terminal" { spawn "kitty" "--title" "a {b} // c"; } // keep
    Mod+W { close-window; }
    /- Mod+F { fullscreen-window; }
}
''')
        self.env = patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.base), "NIRI_CONFIG": str(self.path),
                                           "NAYORI_NIRI_FORBID_LIVE": "1"})
        self.env.start()
        self.addCleanup(self.env.stop)

    def state(self):
        return kb.snapshot(self.path)

    def apply(self, operation, row=None, validator=lambda _path: True, **values):
        request = {"operation": operation, "revision": self.state()["revision"], **values}
        if row:
            request["id"] = row["id"]
        with patch.object(kb.config, "live_reload", side_effect=AssertionError("no live IPC")):
            return kb.config.apply_changes(self.path, {"keybinds": request}, validator=validator)

    def niri_rows(self):
        return [row for row in self.state()["rows"] if row["adapter"] == "niri"]

    def test_include_rebind_reset_preserves_bytes_and_backup(self):
        before = self.child.read_bytes()
        root = self.path.read_bytes()
        row = self.niri_rows()[0]
        result = self.apply("rebind", row, keys="Super+F10")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self.path.read_bytes(), root)
        after = self.child.read_text()
        self.assertIn('"Super+F10" repeat=false', after)
        self.assertIn('spawn "kitty" "--title" "a {b} // c";', after)
        self.assertIn('/* outer /* nested */ comment */', after)
        self.assertIn('} // keep', after)
        self.assertEqual(Path(result["backups"][0]).read_bytes(), before)
        restarted = self.niri_rows()[0]
        self.assertEqual(restarted["defaultKeys"], "Mod+Return")
        self.assertTrue(self.apply("reset", restarted)["ok"])
        self.assertIn('"Mod+Return" repeat=false', self.child.read_text())

    def test_validation_failure_rolls_back(self):
        before = self.child.read_bytes()
        result = self.apply("rebind", self.niri_rows()[0], keys="Super+F9", validator=lambda _path: False)
        self.assertFalse(result["ok"])
        self.assertTrue(result["rolledBack"])
        self.assertEqual(self.child.read_bytes(), before)

    def test_write_failure_preserves_file(self):
        before = self.child.read_bytes()
        original = kb.config.atomic_write
        calls = []

        def fail_once(path, text):
            calls.append(path)
            if len(calls) == 1:
                raise OSError("fixture denied")
            return original(path, text)
        with patch.object(kb.config, "atomic_write", side_effect=fail_once):
            result = self.apply("rebind", self.niri_rows()[0], keys="Super+F9")
        self.assertFalse(result["ok"])
        self.assertEqual(self.child.read_bytes(), before)

    def test_stale_revision_rejected(self):
        state = self.state()
        self.child.write_text(self.child.read_text() + '// concurrent edit\n')
        before = self.child.read_bytes()
        result = kb.config.apply_changes(self.path, {"keybinds": {"operation": "rebind", "id": state["rows"][0]["id"],
            "keys": "Super+F9", "revision": state["revision"]}}, validator=lambda _path: True)
        self.assertFalse(result["ok"])
        self.assertEqual(self.child.read_bytes(), before)

    def test_create_disable_reenable_delete(self):
        child = self.child.read_bytes()
        result = self.apply("create", keys="Super+F11", title="My action", kind="command", value='printf "%s" "hello world"', category="Custom")
        self.assertTrue(result["ok"], result)
        row = next(row for row in self.niri_rows() if row["custom"])
        self.assertIn('"hello world"', row["action"])
        self.assertTrue(self.apply("toggle", row)["ok"])
        row = next(row for row in self.niri_rows() if row["custom"])
        self.assertFalse(row["enabled"])
        self.assertTrue(self.apply("toggle", row)["ok"])
        row = next(row for row in self.niri_rows() if row["custom"])
        self.assertTrue(row["enabled"])
        self.assertTrue(self.apply("delete", row)["ok"])
        self.assertFalse(any(row["custom"] for row in self.niri_rows()))
        self.assertEqual(self.child.read_bytes(), child)

    def test_edit_custom_parameters_and_keep_disabled_state(self):
        self.assertTrue(self.apply("create", keys="Super+F11", title="Original", kind="command", value='printf "old"', category="Custom")["ok"])
        row = next(row for row in self.niri_rows() if row["custom"])
        self.assertTrue(self.apply("toggle", row)["ok"])
        row = next(row for row in self.niri_rows() if row["custom"])
        result = self.apply("update", row, keys="Super+F12", title="Changed", kind="url", value="https://example.org", category="Apps")
        self.assertTrue(result["ok"], result)
        row = next(row for row in self.niri_rows() if row["custom"])
        self.assertEqual(row["title"], "Changed")
        self.assertEqual(row["kind"], "url")
        self.assertEqual(row["category"], "Apps")
        self.assertEqual(row["keys"], "Super+F12")
        self.assertFalse(row["enabled"])
        self.assertIn('spawn "xdg-open" "https://example.org";', row["action"])
        self.assertIn('hotkey-overlay-title="Changed"', self.path.read_text())

    def test_crlf_survives_surgical_rebind(self):
        self.child.write_bytes(b'binds {\r\n    Mod+Return { spawn "kitty"; } // keep\r\n}\r\n')
        result = self.apply("rebind", self.niri_rows()[0], keys="Super+F10")
        self.assertTrue(result["ok"], result)
        self.assertIn(b'Super+F10 { spawn "kitty"; } // keep\r\n}\r\n', self.child.read_bytes())

    def test_new_conflict_and_unknown_keys_do_not_write(self):
        before = self.path.read_bytes()
        for key in ("Super+Return", "Ctrl+DefinitelyNotAnXkbKey", "Super+Return\nmalformed"):
            result = self.apply("create", keys=key, title="Conflict", kind="niri", value="close-window")
            self.assertFalse(result["ok"], result)
            self.assertEqual(self.path.read_bytes(), before)

    def test_actions_never_execute(self):
        sentinel = self.base / "should-not-exist"
        result = self.apply("create", keys="Super+F12", title="Command", kind="command", value=f'touch "{sentinel}"')
        self.assertTrue(result["ok"], result)
        self.assertFalse(sentinel.exists())
        self.assertTrue(kb.custom_action("url", "https://example.org?a=1&b=2").startswith('spawn "xdg-open"'))
        with self.assertRaises(kb.config.ApplyError):
            kb.custom_action("url", "javascript:alert(1)")
        with self.assertRaises(kb.config.ApplyError):
            kb.custom_action("niri", "close-window; quit")

    def test_app_role_is_explicit_and_preserves_comments(self):
        result = self.apply("rebind", self.niri_rows()[0], keys="Mod+Return", appRole="terminal")
        self.assertTrue(result["ok"], result)
        text = self.child.read_text()
        self.assertIn('"call" "apps" "terminal"', text)
        self.assertIn('} // keep', text)
        self.assertIn('repeat=false', text)
        row = self.niri_rows()[0]
        self.assertEqual(row["source"], "Nayori")
        self.assertEqual(row["category"], "Apps")

    def test_positional_override_is_inactive_not_conflicting(self):
        self.path.write_text('binds { Mod+W { fullscreen-window; } }\ninclude "cfg/binds.kdl"\nbinds { Super+W { toggle-overview; } }\n')
        rows = self.niri_rows()
        matches = [row for row in rows if kb.canonical(row["keys"]) == kb.canonical("Super+W")]
        self.assertEqual(len(matches), 3)
        self.assertEqual(sum(row.get("active", True) for row in matches), 1)
        self.assertEqual(kb.conflicts(rows), [])

    def test_same_block_duplicate_and_scopes(self):
        def row(identity, keys, source="Niri", scope="global", enabled=True):
            return {"id": identity, "keys": keys, "source": source, "title": identity, "scope": scope, "enabled": enabled}
        rows = [row("one", "Mod+Ctrl+A"), row("two", "control+win+a", "Nayori"),
                row("disabled", "Super+Ctrl+A", enabled=False), row("kitty", "Ctrl+A", "Kitty", "application:kitty"),
                row("other", "Ctrl+A", "Other", "application:other")]
        result = kb.conflicts(rows)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["severity"], "confirmed")
        self.assertEqual(result[0]["actions"], ["one", "two"])
        rows.append(row("global", "Ctrl+A"))
        self.assertEqual(sum(item["severity"] == "potential" for item in kb.conflicts(rows)), 2)
        self.assertEqual(kb.canonical("Control+Super+Super_L"), kb.canonical("Ctrl+Super_L"))

    def test_optional_external_include_and_mod_key(self):
        external = self.base / "outside.kdl"
        external.write_text('input { mod-key "Alt"; }\nbinds { Mod+F2 { close-window; } }\n')
        self.path.write_text(f'include optional=true "missing.kdl"\ninclude "{external}"\n')
        state = self.state()
        self.assertEqual(state["warnings"], [])
        self.assertEqual(state["mod"], "Alt")
        result = self.apply("rebind", self.niri_rows()[0], keys="Ctrl+F2")
        self.assertTrue(result["ok"], result)
        self.assertIn('Ctrl+F2', external.read_text())

    def test_missing_include_refuses_write(self):
        self.path.write_text(self.path.read_text() + 'include "missing.kdl"\n')
        before = self.child.read_bytes()
        result = self.apply("rebind", self.niri_rows()[0], keys="Super+F10")
        self.assertFalse(result["ok"])
        self.assertEqual(self.child.read_bytes(), before)

    def test_kitty_declared_maps_are_read_only(self):
        folder = self.base / "kitty"
        folder.mkdir()
        (folder / "kitty.conf").write_text('include extra.conf\nmap ctrl+shift+c copy_to_clipboard\n')
        (folder / "extra.conf").write_text('map ctrl+v paste_from_clipboard\n')
        rows, warnings = kb.KittyAdapter().read(self.base)
        self.assertEqual(warnings, [])
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(not row["editable"] and row["scope"] == "application:kitty" for row in rows))

    @unittest.skipUnless(shutil.which("niri"), "niri validate unavailable")
    def test_real_validation_without_session(self):
        # Use the actual validator, never niri msg, on disposable files only.
        self.child.write_text('binds {\n    Mod+Return { spawn "kitty"; }\n}\n')
        baseline = subprocess.run(["niri", "validate", "-c", str(self.path)], capture_output=True, text=True)
        self.assertEqual(baseline.returncode, 0, baseline.stdout + baseline.stderr)
        result = self.apply("rebind", self.niri_rows()[0], keys="Super+F10", validator=kb.config.niri_validate)
        self.assertTrue(result["ok"], result)
        result = self.apply("create", keys="Super+F11", title="New", kind="niri", value="close-window", validator=kb.config.niri_validate)
        self.assertTrue(result["ok"], result)
        before = self.path.read_bytes()
        with patch.object(kb, "custom_action", return_value="definitely-not-a-niri-action;"):
            result = self.apply("create", keys="Super+F12", title="Invalid", kind="niri", value="close-window", validator=kb.config.niri_validate)
        self.assertFalse(result["ok"])
        self.assertEqual(self.path.read_bytes(), before)


def smoke():
    with tempfile.TemporaryDirectory(prefix="nayori-keybind-smoke-") as temporary:
        base = Path(temporary)
        path = base / "config/niri/config.kdl"
        path.parent.mkdir(parents=True)
        path.write_text('binds {\n    Mod+Return hotkey-overlay-title="Terminal" { spawn "kitty"; }\n}\n')
        binary = base / "bin"
        binary.mkdir()
        log = base / "niri.log"
        fake = binary / "niri"
        fake.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\n'
                        'with Path(os.environ["KEYBINDS_LOG"]).open("a") as stream: stream.write(" ".join(sys.argv[1:])+"\\n")\n'
                        'sys.exit(0)\n')
        fake.chmod(0o700)
        env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"], NIRI_CONFIG=str(path),
                   KEYBINDS_LOG=str(log), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   QS_DISABLE_FILE_WATCHER="1", XDG_CONFIG_HOME=str(base / "config"),
                   XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"))
        for name in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET", "NAYORI_NIRI_FORBID_LIVE"):
            env.pop(name, None)
        completed = subprocess.run(["qs", "-p", str(ROOT / "tests/smoke/KeybindsSmoke.qml"), "--no-color"],
                                   env=env, capture_output=True, text=True, timeout=25)
        output = completed.stdout + completed.stderr
        assert completed.returncode == 0 and "KEYBINDS_SMOKE_PASS" in output, output
        assert not any(word in output for word in ("TypeError", "ReferenceError", "Unable to assign", "FAIL", "Failed to load")), output
        commands = log.read_text().splitlines()
        assert any(command.startswith("validate -c ") for command in commands), commands
        assert all(command.startswith(("validate -c ", "msg action load-config-file")) for command in commands), commands
        print(output)


if __name__ == "__main__":
    if "--smoke" in sys.argv:
        smoke()
    else:
        unittest.main()
