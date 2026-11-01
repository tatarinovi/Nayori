#!/usr/bin/env python3
"""Installer tests use only TemporaryDirectory, fake packages and headless Textual."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts.installer.core import (
    CATALOG,
    Engine,
    InstallError,
    Paths,
    Runner,
    Transaction,
    inventory,
    resolve_components,
    validate_pam,
)


class FakeRunner(Runner):
    def __init__(self):
        self.commands = []
        self.installed = set()
        self.unavailable = set()
        self.fail = set()
        self.real_niri = False
        self.have_helper = True

    def helper(self, preferred=None):
        return (preferred or "paru") if self.have_helper else None

    def capture(self, argv):
        self.commands.append(argv)
        if argv[0] == "git":
            return 0, "" if "status" in argv else "fixture-commit"
        if argv[0] == "niri":
            return Runner().capture(argv) if self.real_niri else (0, "valid")
        if "-Q" in argv:
            return (0, "installed") if argv[-1] in self.installed else (1, "missing")
        if "-Si" in argv:
            return (
                (1, "unavailable")
                if argv[-1] in self.unavailable or argv[0] == "false"
                else (0, "available")
            )
        return 1, "not running"

    def run(self, argv):
        self.commands.append(argv)
        return 1 if any(item in self.fail for item in argv) else 0


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nayori-installer-test-")
        self.root = Path(self.temp.name)
        home = self.root / "home with spaces"
        home.mkdir()
        self.paths = Paths({"HOME": str(home)})
        self.source = self.root / "source"
        self.source.mkdir()
        for directory in (
            "tokens",
            "services",
            "surfaces",
            "islands",
            "assets",
            "pam",
            "scripts/installer",
        ):
            (self.source / directory).mkdir(parents=True)
        (self.source / "shell.qml").write_text("import QtQuick\nQtObject {}\n")
        (self.source / "pam/nayori-lock").write_text("auth required pam_unix.so\n")
        shutil.copyfile(
            ROOT / "scripts/installer/launcher.py",
            self.source / "scripts/installer/launcher.py",
        )
        shutil.copytree(ROOT / "configs", self.source / "configs")
        self.runner = FakeRunner()
        self.engine = Engine(self.paths, self.runner, self.source)

    def tearDown(self):
        self.temp.cleanup()


class EngineTests(Fixture):
    def test_dependency_and_conflicts(self):
        self.assertEqual(
            resolve_components({"lock", "autostart"}), {"lock", "autostart", "nayori"}
        )
        catalog = copy.deepcopy(CATALOG)
        catalog["components"]["lock"]["conflicts"] = ["nayori"]
        with self.assertRaises(InstallError):
            resolve_components({"lock"}, catalog)

    def test_package_failure_blocks_dependents_but_not_others(self):
        self.runner.fail = {"quickshell"}
        log = []
        self.engine.log = log.append
        result = self.engine.apply({"autostart", "clipboard", "fonts"}, set())
        self.assertEqual(result["components"], ["fonts"])
        self.assertFalse(self.paths.base.exists())
        self.assertTrue(any("ЗАБЛОКИРОВАН" in line for line in log))

    def test_missing_helper_and_unavailable(self):
        self.runner.have_helper = False
        plan = self.engine.preflight(set(), {"zen-browser-bin"})
        self.assertFalse(plan["packages"]["zen-browser-bin"]["available"])
        self.assertFalse(self.paths.state.exists())

    def test_requested_apps_and_preferred_yay(self):
        apps = CATALOG["apps"]
        self.assertEqual(
            {key for key, item in apps.items() if item["category"] == "Браузеры"},
            {"helium-browser-bin", "zen-browser-bin", "firefox", "chromium"},
        )
        self.assertEqual(
            {key for key, item in apps.items() if item["category"] == "Разработка"},
            {"git", "neovim", "zed", "openai-codex", "claude-desktop", "docker"},
        )
        self.assertEqual(
            {key for key, item in apps.items() if item["category"] == "Офис и заметки"},
            {"openoffice-bin", "obsidian"},
        )
        self.assertTrue(
            {
                "spotify-launcher", "yandex-music", "bitwarden", "qbittorrent",
                "localsend", "qthrone-bin", "shelly",
            }
            <= apps.keys()
        )
        self.engine.apply(set(), {"yandex-music"})
        command = next(cmd for cmd in self.runner.commands if "-S" in cmd)
        self.assertEqual(command[0], "yay")
        self.assertEqual(command[-1], "yandex-music")

    def test_auto_package_falls_back_to_aur_and_reports_missing(self):
        original_capture = self.runner.capture

        def capture(argv):
            if argv[:2] == ["pacman", "-Si"] and argv[-1] == "shelly":
                self.runner.commands.append(argv)
                return 1, "not in repositories"
            return original_capture(argv)

        self.runner.capture = capture
        plan = self.engine.preflight(set(), {"shelly"})
        self.assertEqual(plan["packages"]["shelly"]["source"], "aur")
        self.assertTrue(plan["packages"]["shelly"]["available"])
        self.runner.have_helper = False
        plan = self.engine.preflight(set(), {"shelly"})
        self.assertFalse(plan["packages"]["shelly"]["available"])

    def test_aur_helper_disappearing_after_preflight_is_skipped(self):
        plan = self.engine.preflight(set(), {"yandex-music"})
        self.assertTrue(plan["packages"]["yandex-music"]["available"])
        self.runner.have_helper = False
        messages = []
        self.engine.log = messages.append
        with patch.object(self.engine, "preflight", return_value=plan):
            result = self.engine.apply(set(), {"yandex-music"})
        self.assertEqual(result["apps"], [])
        self.assertTrue(any("AUR helper недоступен" in message for message in messages))

    def test_repeated_install_modified_and_rollback(self):
        first = self.engine.apply({"nayori"}, set())
        old = (self.paths.base / "current").resolve()
        manifest = json.loads((old / "manifest.json").read_text())
        self.assertEqual(manifest["commit"], "fixture-commit")
        self.assertIn("shell.qml", manifest["files"])
        launcher = self.paths.bin / "nayori"
        launcher.write_text("custom\n")
        with self.assertRaises(InstallError):
            self.engine.apply({"nayori"}, set())
        second = self.engine.apply({"nayori"}, set(), allow_modified=True)
        self.assertNotEqual(first["id"], second["id"])
        self.assertNotEqual((self.paths.base / "current").resolve(), old)
        self.engine.restore(rollback=True)
        self.assertEqual((self.paths.base / "current").resolve(), old)
        self.assertEqual(launcher.read_text(), "custom\n")
        self.assertFalse(any("-R" in cmd for cmd in self.runner.commands))

    def test_copy_failure_preserves_active(self):
        self.engine.apply({"nayori"}, set())
        original = (self.paths.base / "current").readlink()
        with patch(
            "scripts.installer.core.shutil.copytree", side_effect=OSError("disk full")
        ):
            with self.assertRaises(OSError):
                self.engine.apply({"nayori"}, set())
        self.assertEqual((self.paths.base / "current").readlink(), original)
        self.assertIsNone(self.engine.pending())

    def test_niri_validation_failure_preserves_original(self):
        self.paths.niri.mkdir(parents=True)
        (self.paths.niri / "config.kdl").write_text("original")
        original_capture = self.runner.capture
        self.runner.capture = lambda argv: (
            (1, "invalid") if argv[0] == "niri" else original_capture(argv)
        )
        with self.assertRaises(InstallError):
            self.engine.apply({"niri"}, set())
        self.assertEqual((self.paths.niri / "config.kdl").read_text(), "original")

    def test_niri_preset_uses_strata_and_preserves_original_directory(self):
        self.paths.niri.mkdir(parents=True)
        (self.paths.niri / "config.kdl").write_text("original")
        (self.paths.niri / "custom.kdl").write_text("custom")
        with patch("scripts.installer.core.shutil.which", return_value=None):
            plan = self.engine.preflight({"niri"}, set())
            self.assertTrue(any("Strata" in problem for problem in plan["problems"]))
            self.assertNotIn("thunar", plan["packages"])
            self.assertNotIn("thunar", CATALOG["apps"])
            transaction = self.engine.apply({"niri"}, set())
        backup = self.paths.config / (".niri.nayori-backup-" + transaction["id"])
        self.assertEqual((backup / "config.kdl").read_text(), "original")
        self.assertEqual((backup / "custom.kdl").read_text(), "custom")
        binds = (self.paths.niri / "cfg/keybinds.kdl").read_text()
        self.assertIn('Mod+E { spawn "strata"; }', binds)
        self.engine.restore(rollback=True)
        self.assertEqual((self.paths.niri / "config.kdl").read_text(), "original")
        self.assertEqual((self.paths.niri / "custom.kdl").read_text(), "custom")

    def test_niri_plan_accepts_existing_strata(self):
        with patch("scripts.installer.core.shutil.which", return_value="/test/strata"):
            plan = self.engine.preflight({"niri"}, set())
        self.assertFalse(any("Strata" in problem for problem in plan["problems"]))

    def test_autostart_manual_command_handles_unicode_and_preserves_niri(self):
        home = self.root / 'пользователь "test"'
        home.mkdir()
        paths = Paths({"HOME": str(home)})
        paths.niri.mkdir(parents=True)
        config = paths.niri / "config.kdl"
        config.write_text("// original\n")
        messages = []
        engine = Engine(paths, FakeRunner(), self.source, messages.append)
        engine.apply({"autostart"}, set())
        line = next(m for m in messages if m.startswith("Добавьте в niri вручную: "))
        command = line.removeprefix("Добавьте в niri вручную: ")
        self.assertIn("пользователь", command)
        self.assertIn('\\"test\\"', command)
        self.assertEqual(config.read_text(), "// original\n")
        if shutil.which("niri"):
            fixture = self.root / "autostart-test.kdl"
            fixture.write_text(command + "\n")
            result = subprocess.run(
                ["niri", "validate", "-c", str(fixture)], capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_niri_symlink_preserved_and_real_validation(self):
        if not shutil.which("niri"):
            self.skipTest("niri unavailable")
        self.runner.real_niri = True
        target = self.root / "original niri"
        target.mkdir()
        (target / "config.kdl").write_text("do not change")
        self.paths.config.mkdir(parents=True)
        self.paths.niri.symlink_to(target, target_is_directory=True)
        self.engine.apply({"niri", "autostart", "lock", "capture", "clipboard"}, set())
        self.assertFalse(self.paths.niri.is_symlink())
        self.assertEqual((target / "config.kdl").read_text(), "do not change")
        binds = (self.paths.niri / "cfg/keybinds.kdl").read_text()
        self.assertIn("home with spaces", binds)
        self.assertNotIn("/home/tatarinov", binds)
        startup = (self.paths.niri / "cfg/autostart.kdl").read_text()
        self.assertEqual(
            startup,
            "spawn-at-startup "
            + json.dumps(str(self.paths.bin / "nayori"), ensure_ascii=False)
            + "\n",
        )
        self.assertTrue((self.paths.bin / "nayori").is_file())
        self.engine.restore(rollback=True)
        self.assertTrue(self.paths.niri.is_symlink())

    def test_pam_permissions_content_links_owner_and_race(self):
        path = self.source / "pam/nayori-lock"
        validate_pam(path, self.source)
        for contents in (
            "auth sufficient pam_unix.so\n",
            "auth required pam_unix.so\nauth optional pam_exec.so /bin/true\n",
        ):
            path.write_text(contents)
            with self.assertRaises(InstallError):
                validate_pam(path, self.source)
        path.write_text("auth required pam_unix.so\n")
        path.chmod(0o666)
        with self.assertRaises(InstallError):
            validate_pam(path, self.source)
        path.chmod(0o644)
        original = Path.lstat

        def fake_owner(item):
            info = original(item)
            if item == path:
                values = list(info)
                values[4] = 424242
                return os.stat_result(values)
            return info

        with patch.object(Path, "lstat", fake_owner):
            with self.assertRaises(InstallError):
                validate_pam(path, self.source)
        moved = path.with_name("real")
        path.rename(moved)
        path.symlink_to(moved)
        with self.assertRaises(InstallError):
            validate_pam(path, self.source)
        path.unlink()
        moved.rename(path)
        original_open = os.open

        def replace_at_open(name, flags, *args, **kwargs):
            if Path(name) == path:
                replacement = path.with_name("replacement")
                replacement.write_text("auth required pam_unix.so\n")
                os.replace(replacement, path)
            return original_open(name, flags, *args, **kwargs)

        with patch("scripts.installer.core.os.open", replace_at_open):
            with self.assertRaises(InstallError):
                validate_pam(path, self.source)

    def test_cancel_finishes_one_package_and_stops(self):
        def run(argv):
            self.engine.cancelled = True
            self.runner.commands.append(argv)
            return 0

        self.runner.run = run
        with self.assertRaises(InstallError):
            self.engine.apply({"nayori"}, set())
        self.assertFalse(self.paths.base.exists())
        self.assertEqual(sum("-S" in cmd for cmd in self.runner.commands), 1)

    def test_retry_and_sudo_failure(self):
        calls = []

        def run(argv):
            calls.append(argv)
            return 1 if len(calls) == 1 else 0

        self.runner.run = run
        self.engine.apply(set(), {"btop"}, on_package_error=lambda pkg: "retry")
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][:3], ["sudo", "pacman", "-S"])
        self.assertTrue(all("--noconfirm" in call for call in calls))

    def test_app_confirmation_does_not_change_components_or_upgrade(self):
        self.engine.apply({"nayori"}, {"btop", "zen-browser-bin"}, update=True)
        commands = [cmd for cmd in self.runner.commands if "-S" in cmd or "-Syu" in cmd]
        update = next(cmd for cmd in commands if "-Syu" in cmd)
        repo_app = next(cmd for cmd in commands if cmd[-1] == "btop")
        aur_app = next(cmd for cmd in commands if cmd[-1] == "zen-browser-bin")
        component = next(cmd for cmd in commands if cmd[-1] == "quickshell")
        self.assertNotIn("--noconfirm", update)
        self.assertNotIn("--noconfirm", component)
        self.assertIn("--noconfirm", repo_app)
        self.assertIn("--noconfirm", aur_app)
        self.assertEqual(aur_app[0], "paru")

    def test_blocked_app_does_not_automate_shared_component_package(self):
        plan = self.engine.preflight({"nayori"}, {"btop"})
        plan["packages"]["btop"]["owners"].append("nayori")
        plan["blocked_components"]["app:btop"] = "unavailable"
        with patch.object(self.engine, "preflight", return_value=plan):
            self.engine.apply({"nayori"}, {"btop"})
        command = next(
            cmd for cmd in self.runner.commands if "-S" in cmd and cmd[-1] == "btop"
        )
        self.assertNotIn("--noconfirm", command)

    def test_diagnostic_read_only(self):
        before = inventory(self.root)
        report = self.engine.diagnose()
        self.assertTrue(any(item["title"] == "Версия" for item in report))
        self.assertEqual(inventory(self.root), before)

    def test_rename_crash_recovery_after_original_move(self):
        self.engine.ensure_writable()
        dest = self.root / "destination"
        stage = self.root / "staged"
        dest.write_text("old")
        stage.write_text("new")
        tx = Transaction(self.paths)
        original = os.replace

        def crash(src, dst):
            if Path(src) == stage:
                raise KeyboardInterrupt("power loss")
            return original(src, dst)

        with patch("scripts.installer.core.os.replace", crash):
            with self.assertRaises(KeyboardInterrupt):
                tx.replace(dest, stage)
        self.assertFalse(dest.exists())
        self.assertIsNotNone(self.engine.pending())
        self.engine.restore()
        self.assertEqual(dest.read_text(), "old")
        self.assertIsNone(self.engine.pending())

    def test_pointer_switch_failure_keeps_old_version(self):
        self.engine.apply({"nayori"}, set())
        old = (self.paths.base / "current").resolve()
        original = os.replace

        def fail(src, dst):
            if Path(src).name.startswith(".current-"):
                raise OSError("rename failed")
            return original(src, dst)

        with patch("scripts.installer.core.os.replace", fail):
            with self.assertRaises(OSError):
                self.engine.apply({"nayori"}, set())
        self.assertEqual((self.paths.base / "current").resolve(), old)

    def test_restore_crash_after_backup_restored(self):
        self.engine.ensure_writable()
        dest, staged = self.root / "dest", self.root / "stage"
        dest.write_text("old")
        staged.write_text("new")
        tx = Transaction(self.paths)
        tx.replace(dest, staged)
        original = os.replace

        def crash(src, dst):
            result = original(src, dst)
            if ".nayori-backup-" in str(src):
                raise KeyboardInterrupt("power loss")
            return result

        with patch("scripts.installer.core.os.replace", crash):
            with self.assertRaises(KeyboardInterrupt):
                tx.restore()
        self.engine.restore()
        self.assertEqual(dest.read_text(), "old")

    def test_conflicting_changes_preserved_on_explicit_restore(self):
        self.engine.apply({"nayori"}, set())
        launcher = self.paths.bin / "nayori"
        launcher.write_text("local change")
        with self.assertRaises(InstallError):
            self.engine.restore(rollback=True)
        self.engine.restore(rollback=True, allow_modified=True)
        saved = list(launcher.parent.glob(".*.nayori-displaced-*"))
        self.assertTrue(any(path.read_text() == "local change" for path in saved))

    def test_pointer_replacement_is_atomic(self):
        self.engine.apply({"nayori"}, set())
        original = os.replace
        observations = []

        def observe(src, dst):
            if Path(src).name.startswith(".current-"):
                observations.append((self.paths.base / "current").is_symlink())
            if Path(src) == self.paths.base / "current":
                self.fail("Active pointer must never be moved out of the way")
            return original(src, dst)

        with patch("scripts.installer.core.os.replace", observe):
            self.engine.apply({"nayori"}, set())
        self.assertEqual(observations, [True])

    def test_legacy_migration_and_rollback(self):
        self.paths.base.mkdir(parents=True)
        (self.paths.base / "shell.qml").write_text("legacy")
        (self.paths.base / "custom").write_text("preserve")
        self.engine.apply({"nayori"}, set())
        self.assertTrue((self.paths.base / "current").is_symlink())
        self.assertFalse((self.paths.base / "custom").exists())
        self.engine.restore(rollback=True)
        self.assertEqual((self.paths.base / "custom").read_text(), "preserve")
        self.assertEqual((self.paths.base / "shell.qml").read_text(), "legacy")

    def test_external_manifest_survives_apps_only_install(self):
        self.engine.apply({"nayori"}, set())
        self.engine.apply(set(), {"btop"})
        launcher = self.paths.bin / "nayori"
        launcher.write_text("local change")
        self.assertIn(str(launcher), self.engine.modified_files())
        installed = json.loads((self.paths.state / "installed.json").read_text())
        self.assertIn("nayori", installed["components"])
        self.assertTrue(installed["active_version"])

    def test_pulse_conflict_blocks_visualizer(self):
        self.runner.installed = {"pulseaudio"}
        plan = self.engine.preflight({"visualizer"}, set())
        self.assertIn("visualizer", plan["blocked_components"])
        result = self.engine.apply({"visualizer"}, set())
        self.assertNotIn("visualizer", result["components"])
        self.assertFalse(
            any(
                "pipewire-pulse" in command and "-S" in command
                for command in self.runner.commands
            )
        )

    def test_full_repository_copy_is_verified_without_live_install(self):
        self.engine.source = ROOT
        self.engine.apply({"nayori"}, set())
        current = (self.paths.base / "current").resolve()
        self.assertTrue((current / "sddm/nayori/Main.qml").is_file())
        self.assertTrue((current / "configs/niri/config.kdl").is_file())
        self.assertEqual(self.engine.modified_files(), [])


class SddmTests(unittest.TestCase):
    def test_existing_standalone_cli_and_backups(self):
        with tempfile.TemporaryDirectory(
            prefix="nayori-sddm-legacy-test-"
        ) as directory:
            command = [
                sys.executable,
                str(ROOT / "scripts/install-sddm.py"),
                "--owner",
                str(os.getuid()),
                "--root",
                directory,
                "--select-theme",
            ]
            for _ in range(2):
                result = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            theme = Path(directory) / "usr/share/sddm/themes/nayori"
            self.assertTrue((theme / "components/AuthView.qml").is_file())
            self.assertTrue(list(theme.parent.glob("nayori.bak-*")))

    def test_transactional_theme_install_and_restore(self):
        spec = importlib.util.spec_from_file_location(
            "sddm_installer", ROOT / "scripts/install-sddm.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(prefix="nayori-sddm-test-") as directory:
            root = Path(directory)
            theme = root / "usr/share/sddm/themes/nayori"
            theme.mkdir(parents=True)
            (theme / "old").write_text("original")
            uid = "a" * 32
            module.transactional(root, pwd.getpwuid(os.getuid()), True, uid)
            self.assertTrue((theme / "Main.qml").is_file())
            self.assertEqual(
                (root / "etc/sddm.conf.d/90-nayori.conf").read_text(),
                "[Theme]\nCurrent=nayori\n",
            )
            module.transactional(root, transaction_id=uid, rollback=True)
            self.assertEqual((theme / "old").read_text(), "original")
            self.assertFalse((root / "etc/sddm.conf.d/90-nayori.conf").exists())


class LauncherTests(unittest.TestCase):
    def test_ipc_pinned_to_running_version_after_switch(self):
        with tempfile.TemporaryDirectory(prefix="nayori-launcher-test-") as directory:
            root = Path(directory)
            base, runtime, binaries = root / "base", root / "run", root / "bin"
            for directory in (runtime, binaries):
                directory.mkdir(mode=0o700)
            for version in ("one", "two"):
                release = base / "releases" / version
                release.mkdir(parents=True)
                (release / "manifest.json").write_text('{"components": []}')
            (base / "current").symlink_to("releases/one")
            launcher = root / "launcher"
            launcher.write_text(
                (ROOT / "scripts/installer/launcher.py")
                .read_text()
                .replace("INSTALL_BASE = None", "INSTALL_BASE = " + repr(str(base)))
            )
            launcher.chmod(0o755)
            fake = binaries / "qs"
            fake.write_text(
                '#!/usr/bin/env python3\nimport sys,time\nif "ipc" in sys.argv: print(" ".join(sys.argv)); sys.exit(0)\ntime.sleep(20)\n'
            )
            fake.chmod(0o755)
            env = dict(
                os.environ,
                XDG_RUNTIME_DIR=str(runtime),
                PATH=str(binaries) + ":" + os.environ["PATH"],
            )
            process = subprocess.Popen(
                [str(launcher)], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            try:
                import time

                for _ in range(100):
                    if (runtime / "nayori/active.json").exists():
                        break
                    time.sleep(0.02)
                self.assertIsNone(process.poll())
                pointer = base / "next"
                pointer.symlink_to("releases/two")
                os.replace(pointer, base / "current")
                output = subprocess.check_output(
                    [str(launcher), "ipc", "settings", "open"], env=env, text=True
                )
                self.assertIn("releases/one", output)
                self.assertNotIn("releases/two", output)
            finally:
                process.terminate()
                process.communicate(timeout=5)


class BootstrapTests(unittest.TestCase):
    def test_bootstrap_and_read_only_modes_with_fake_commands(self):
        if os.getuid() == 0:
            self.skipTest("Bootstrap intentionally refuses root")
        import pty
        import select

        with tempfile.TemporaryDirectory(prefix="nayori-bootstrap-test-") as directory:
            root = Path(directory)
            script = root / "install.sh"
            shutil.copyfile(ROOT / "install.sh", script)
            fake = root / "bin"
            fake.mkdir()
            trace = root / "trace"
            for name, body in {
                "pacman": "exit 0",
                "sudo": 'echo sudo >> "$BOOTSTRAP_TRACE"; printf "#!/bin/bash\\nexit 0\\n" > "$BOOTSTRAP_BIN/gum"; /bin/chmod +x "$BOOTSTRAP_BIN/gum"',
                "python3": 'echo ui >> "$BOOTSTRAP_TRACE"; exit 0',
            }.items():
                path = fake / name
                path.write_text("#!/bin/bash\n" + body + "\n")
                path.chmod(0o755)
            for name in ("uname", "dirname"):
                (fake / name).symlink_to(shutil.which(name))
            env = dict(
                os.environ,
                HOME=str(root),
                PATH=str(fake),
                TERM="xterm",
                BOOTSTRAP_TRACE=str(trace),
                BOOTSTRAP_BIN=str(fake),
            )

            def run(arguments, answer=b""):
                master, slave = pty.openpty()
                proc = subprocess.Popen(
                    ["/bin/bash", str(script), *arguments],
                    stdin=slave,
                    stdout=slave,
                    stderr=slave,
                    env=env,
                )
                os.close(slave)
                if answer:
                    os.write(master, answer)
                output = b""
                try:
                    import time

                    end = time.monotonic() + 5
                    while time.monotonic() < end:
                        ready, _, _ = select.select([master], [], [], 0.05)
                        if ready:
                            try:
                                chunk = os.read(master, 8192)
                            except OSError:
                                break
                            if not chunk:
                                break
                            output += chunk
                        if proc.poll() is not None:
                            break
                    proc.wait(timeout=2)
                    return proc.returncode, output.decode()
                finally:
                    if proc.poll() is None:
                        proc.kill()
                        proc.wait()
                    os.close(master)

            for option in ("--dry-run", "--diagnose"):
                code, output = run([option])
                self.assertNotEqual(code, 0)
                self.assertIn("bootstrap отключён", output)
                self.assertFalse(trace.exists())
            self.assertEqual(run([], b"n\n")[0], 0)
            self.assertFalse(trace.exists())
            self.assertEqual(run([], b"y\n")[0], 0)
            self.assertEqual(trace.read_text().splitlines(), ["sudo", "ui"])


class FakeGum:
    def __init__(self, choices=(), confirmations=(), inputs=()):
        self.choices = list(choices)
        self.confirmations = list(confirmations)
        self.inputs = list(inputs)
        self.calls = []

    def choose(self, title, labels, selected=(), multiple=False, search=False):
        self.calls.append((title, list(labels), list(selected), multiple, search))
        return self.choices.pop(0)

    def confirm(self, question):
        self.calls.append(question)
        return self.confirmations.pop(0)

    def input(self, prompt):
        self.calls.append(prompt)
        return self.inputs.pop(0)


class UITests(Fixture):
    def test_real_gum_preselected_items_in_pty(self):
        if not shutil.which("gum"):
            self.skipTest("gum unavailable")
        import fcntl
        import pty
        import select
        import struct
        import termios
        import time

        pid, master = pty.fork()
        if pid == 0:
            os.environ["TERM"] = "xterm-256color"
            os.execv(
                sys.executable,
                [
                    sys.executable,
                    "-c",
                    "from scripts.installer.ui import Gum; print('GUM_RESULT', repr(Gum().choose('TEST_MENU', ['first', 'second'], ['second'], True)), flush=True)",
                ],
            )
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        output = b""
        sent = False
        finished = False
        try:
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        chunk = os.read(master, 8192)
                    except OSError:
                        break
                    output += chunk
                    if b"TEST_MENU" in output and not sent:
                        os.write(master, b"\r")
                        sent = True
                done, _ = os.waitpid(pid, os.WNOHANG)
                if done:
                    finished = True
                    break
            self.assertIn(b"GUM_RESULT ['second']", output)
        finally:
            if not finished:
                try:
                    os.kill(pid, 9)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(master)

    def test_components_resolve_dependencies_and_deselect_dependents(self):
        from scripts.installer.ui import InstallerApp

        labels = {
            key: f"{item['label']} [{key}]"
            for key, item in CATALOG["components"].items()
        }
        gum = FakeGum(choices=[[labels["autostart"]], []])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.choose_components()
        self.assertEqual(app.components, {"nayori", "autostart"})
        app.choose_components()
        self.assertEqual(app.components, set())
        self.assertTrue(gum.calls[0][3])
        self.assertEqual(set(gum.calls[1][2]), {labels["nayori"], labels["autostart"]})

    def test_app_categories_keep_selections(self):
        from scripts.installer.ui import InstallerApp

        gum = FakeGum(choices=[["Системные"], ["btop [repo]"], ["Назад"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.choose_apps()
        self.assertEqual(app.apps, {"btop"})
        self.assertTrue(gum.calls[1][4])

    def test_review_is_read_only_until_confirmed(self):
        from scripts.installer.ui import InstallerApp

        before = inventory(self.root)
        gum = FakeGum(confirmations=[False, False])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.apps = {"btop"}
        app.review()
        self.assertEqual(inventory(self.root), before)
        app.dry_run = True
        app.review()
        self.assertEqual(inventory(self.root), before)
        self.assertEqual(len(gum.confirmations), 0)

    def test_review_apply_and_package_error(self):
        from scripts.installer.ui import InstallerApp

        gum = FakeGum(confirmations=[True, True], choices=[["Повторить"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.apps = {"btop"}
        self.assertEqual(app.package_error("btop"), "retry")
        app.review()
        self.assertTrue((self.paths.state / "installed.json").is_file())
        self.assertIn(["sudo", "pacman", "-Syu"], self.runner.commands)
        self.assertTrue(
            any(
                "--noconfirm" in cmd and cmd[-1] == "btop"
                for cmd in self.runner.commands
            )
        )

    def test_review_refuses_modified_files_without_backup_confirmation(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        launcher = self.paths.bin / "nayori"
        launcher.write_text("custom launcher")
        gum = FakeGum(confirmations=[False, False])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.components = {"nayori"}
        app.review()
        self.assertEqual(launcher.read_text(), "custom launcher")
        self.assertIsNone(self.engine.pending())

    def test_diagnostic_restore_requires_exact_confirmation(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        gum = FakeGum(choices=[["Откат"], ["Назад"]], inputs=["нет"])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.diagnostics()
        self.assertTrue((self.paths.base / "current").is_symlink())


if __name__ == "__main__":
    unittest.main(verbosity=2)
