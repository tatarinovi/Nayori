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
    validate_runtime_entrypoints,
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
        if "-Qq" in argv:
            return 0, "\n".join(sorted(self.installed))
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
        (self.source / "ShellSession.qml").write_text("import QtQuick\nQtObject {}\n")
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
        self.assertIn("ShellSession.qml", manifest["files"])
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

    def test_renderer_build_failure_does_not_publish_release(self):
        build = self.source / "scripts/build-widget-renderer.py"
        build.write_text("# fixture build hook\n")
        self.runner.fail.add("python3")
        with self.assertRaisesRegex(InstallError, "отрисовщик"):
            self.engine._copy_release(["nayori"])
        releases = self.paths.base / "releases"
        self.assertEqual(list(releases.iterdir()), [])
        self.assertFalse((self.paths.base / "current").exists())

    def test_renderer_artifact_is_part_of_release_inventory(self):
        build = self.source / "scripts/build-widget-renderer.py"
        build.write_text("# fixture build hook\n")
        original_run = self.runner.run
        def build_fixture(argv):
            if argv[0] == "python3" and argv[1].endswith("build-widget-renderer.py"):
                artifact = Path(argv[1]).parent.parent / "surfaces/fixture.so"
                artifact.write_bytes(b"fixture renderer")
            return original_run(argv)
        self.runner.run = build_fixture
        release = self.engine._copy_release(["nayori"])
        manifest = json.loads((release / "manifest.json").read_text())
        self.assertIn("surfaces/fixture.so", manifest["files"])
        self.assertEqual(manifest["files"]["surfaces/fixture.so"], inventory(release)["surfaces/fixture.so"])

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

    def test_pre_splash_copy_list_keeps_bootstrap_session(self):
        # This is the copy contract of an already-installed pre-splash updater.
        # It cannot learn about new files at the repository root during apply.
        (self.source / "shell.qml").write_text((ROOT / "shell.qml").read_text())
        (self.source / "surfaces/ShellSession.qml").write_text("import Quickshell\nScope {}\n")
        payload = self.root / "legacy-payload"
        payload.mkdir()
        for name in ("shell.qml", "tokens", "services", "surfaces", "islands", "assets", "pam", "scripts"):
            source, target = self.source / name, payload / name
            if source.is_dir():
                shutil.copytree(source, target)
            else:
                shutil.copy2(source, target)
        self.assertFalse((payload / "ShellSession.qml").exists())
        validate_runtime_entrypoints(payload)
        self.assertTrue((payload / "surfaces/ShellSession.qml").is_file())

    def test_missing_startup_session_rejects_release(self):
        (self.source / "shell.qml").write_text((ROOT / "shell.qml").read_text())
        with self.assertRaisesRegex(InstallError, "стартовый QML"):
            self.engine._copy_release(["nayori"])
        self.assertFalse((self.paths.base / "current").exists())
        self.assertEqual(list((self.paths.base / "releases").iterdir()), [])

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

    def test_pacman_and_apps_use_automatic_confirmation(self):
        self.engine.apply({"nayori"}, {"btop", "zen-browser-bin"}, update=True)
        commands = [cmd for cmd in self.runner.commands if "-S" in cmd or "-Syu" in cmd]
        update = next(cmd for cmd in commands if "-Syu" in cmd)
        repo_app = next(cmd for cmd in commands if cmd[-1] == "btop")
        aur_app = next(cmd for cmd in commands if cmd[-1] == "zen-browser-bin")
        component = next(cmd for cmd in commands if cmd[-1] == "quickshell")
        self.assertIn("--noconfirm", update)
        self.assertIn("--noconfirm", component)
        self.assertIn("--noconfirm", repo_app)
        self.assertIn("--noconfirm", aur_app)
        self.assertEqual(aur_app[0], "paru")

    def test_shared_component_package_uses_pacman_confirmation(self):
        plan = self.engine.preflight({"nayori"}, {"btop"})
        plan["packages"]["btop"]["owners"].append("nayori")
        plan["blocked_components"]["app:btop"] = "unavailable"
        with patch.object(self.engine, "preflight", return_value=plan):
            self.engine.apply({"nayori"}, {"btop"})
        command = next(
            cmd for cmd in self.runner.commands if "-S" in cmd and cmd[-1] == "btop"
        )
        self.assertIn("--noconfirm", command)

    def test_aur_component_keeps_its_interactive_questions(self):
        self.engine.apply({"fonts"}, set())
        command = next(
            cmd for cmd in self.runner.commands if "-S" in cmd and cmd[-1] == "ttf-literata"
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
        self.assertTrue((current / "surfaces/ShellSession.qml").is_file())
        validate_runtime_entrypoints(current)
        for name in ("LICENSE", "NOTICE", "LICENSES/OFL-1.1.txt"):
            self.assertTrue((current / name).is_file(), name)
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
                active = runtime / "nayori/active.json"
                record = json.loads(active.read_text())
                stale = dict(record, start="0")
                active.write_text(json.dumps(stale))
                result = subprocess.run([str(launcher), "-stop"], env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIsNone(process.poll())
                active.write_text(json.dumps(record))
                subprocess.run([str(launcher), "-stop"], env=env, check=True)
                process.communicate(timeout=5)
                self.assertFalse(active.exists())
                result = subprocess.run([str(launcher), "-stop"], env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
            finally:
                if process.poll() is None:
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

    def choose(self, title, labels, selected=(), multiple=False):
        self.calls.append((title, list(labels), list(selected), multiple))
        return self.choices.pop(0)

    def confirm(self, question):
        self.calls.append(question)
        return self.confirmations.pop(0)

    def input(self, prompt):
        self.calls.append(prompt)
        return self.inputs.pop(0)


class UITests(Fixture):
    def test_gum_empty_multiselect_is_empty_for_components_and_apps(self):
        from scripts.installer.ui import Gum

        result = subprocess.CompletedProcess([], 0, stdout="\n")
        with patch("scripts.installer.ui.subprocess.run", return_value=result) as run:
            self.assertEqual(Gum().choose("components", ["first"], multiple=True), [])
            self.assertEqual(Gum().choose("apps", ["first"], multiple=True), [])
            self.assertEqual(run.call_args.args[0][1], "choose")

    def test_real_gum_confirmation_uses_tab_and_enter(self):
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
                [sys.executable, "-c", "from scripts.installer.ui import Gum; print('CONFIRM_RESULT', Gum().confirm('TEST_CONFIRM'), flush=True)"],
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
                        output += os.read(master, 8192)
                    except OSError:
                        break
                    if b"TEST_CONFIRM" in output and not sent:
                        os.write(master, b"\t\r")
                        sent = True
                done, status = os.waitpid(pid, os.WNOHANG)
                if done:
                    finished = True
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0)
                    break
            self.assertIn(b"CONFIRM_RESULT True", output)
        finally:
            if not finished:
                try:
                    os.kill(pid, 9)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(master)

    def _check_real_gum_component_selection(self, keys, expected):
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
                    "from scripts.installer.ui import InstallerApp; "
                    "app=InstallerApp(); app.choose_components(); "
                    "print('EMPTY_OK', repr(app.components), flush=True)",
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
                    if b"Enter" in output and not sent:
                        os.write(master, keys)
                        sent = True
                done, status = os.waitpid(pid, os.WNOHANG)
                if done:
                    finished = True
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0)
                    break
            self.assertIn(expected, output)
            self.assertNotIn(b"Traceback", output)
        finally:
            if not finished:
                try:
                    os.kill(pid, 9)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(master)

    def test_real_gum_empty_component_selection_in_pty(self):
        self._check_real_gum_component_selection(b"\r", b"EMPTY_OK set()")

    def test_real_gum_tab_selects_component_in_pty(self):
        self._check_real_gum_component_selection(b"\t\r", b"'nayori'")

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
        self.assertNotIn("Поиск", gum.calls[0][1])
        self.assertTrue(gum.calls[1][3])
        self.assertFalse(any(isinstance(call, str) for call in gum.calls))

    def test_other_categories_preserve_previous_selections(self):
        from scripts.installer.ui import InstallerApp

        gum = FakeGum(choices=[["Браузеры"], ["Firefox [repo]"], ["Назад"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.apps = {"btop"}
        app.choose_apps()
        self.assertEqual(app.apps, {"btop", "firefox"})

    def test_installed_app_is_labeled_in_category(self):
        from scripts.installer.ui import InstallerApp

        self.runner.installed = {"btop"}
        gum = FakeGum(choices=[["Системные"], [], ["Назад"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.choose_apps()
        self.assertIn("btop [repo] [installed]", gum.calls[1][1])
        self.assertNotIn("btop", app.apps)

    def test_installed_status_failure_keeps_apps_selectable(self):
        from scripts.installer.ui import InstallerApp

        original_capture = self.runner.capture
        self.runner.capture = lambda argv: (
            (1, "unavailable")
            if argv == ["pacman", "-Qq"]
            else original_capture(argv)
        )
        gum = FakeGum(choices=[["Системные"], ["btop [repo]"], ["Назад"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.choose_apps()
        self.assertEqual(app.apps, {"btop"})

    def test_selected_installed_app_is_not_reinstalled(self):
        from scripts.installer.ui import InstallerApp

        self.runner.installed = {"btop"}
        gum = FakeGum(
            choices=[["Системные"], ["btop [repo] [installed]"], ["Назад"]]
        )
        app = InstallerApp(engine=self.engine, gum=gum)
        app.choose_apps()
        result = self.engine.apply(set(), app.apps)
        self.assertEqual(result["apps"], ["btop"])
        self.assertFalse(any("-S" in command for command in self.runner.commands))

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

        gum = FakeGum(confirmations=[True, True], choices=[["Повторить"], ["Закрыть"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.apps = {"btop"}
        self.assertEqual(app.package_error("btop"), "retry")
        app.review()
        self.assertTrue((self.paths.state / "installed.json").is_file())
        self.assertIn(["sudo", "pacman", "-Syu", "--noconfirm"], self.runner.commands)
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

    def test_result_screen_launches_only_when_selected(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        gum = FakeGum(choices=[["Запустить Nayori"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        with patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-test"}):
            with patch("scripts.installer.ui.quickshell_running", return_value=False):
                with patch("scripts.installer.ui.subprocess.Popen") as start:
                    self.assertTrue(app.show_result(True, allow_launch=True))
        start.assert_called_once_with(
            [str(self.paths.bin / "nayori")],
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )

    def test_result_screen_does_not_launch_competing_shell(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        gum = FakeGum(choices=[["Запустить Nayori"], ["Закрыть"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        with patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-test"}):
            with patch("scripts.installer.ui.quickshell_running", return_value=True):
                with patch("scripts.installer.ui.subprocess.Popen") as start:
                    self.assertTrue(app.show_result(True, allow_launch=True))
        start.assert_not_called()

    def test_result_screen_closing_does_not_launch_installed_shell(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        app = InstallerApp(engine=self.engine, gum=FakeGum(choices=[["Закрыть"]]))
        with patch("scripts.installer.ui.subprocess.Popen") as start:
            self.assertTrue(app.show_result(True, allow_launch=True))
        start.assert_not_called()

    def test_result_screen_no_launch_when_missing_or_failed(self):
        from scripts.installer.ui import InstallerApp

        gum = FakeGum(choices=[["Закрыть"], ["Закрыть"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        with patch("scripts.installer.ui.subprocess.Popen") as start:
            app.show_result(True, allow_launch=True)
            app.show_result(False)
        start.assert_not_called()
        for call in gum.calls:
            self.assertNotIn("Запустить Nayori", call[1])

    def test_launch_checks_wayland_and_process_inventory(self):
        from scripts.installer.ui import InstallerApp, quickshell_running

        proc = self.root / "proc"
        (proc / "123").mkdir(parents=True)
        (proc / "123" / "comm").write_text("quickshell\n")
        self.assertTrue(quickshell_running(proc))
        (proc / "123" / "comm").write_text("other\n")
        self.assertFalse(quickshell_running(proc))
        self.engine.apply({"nayori"}, set())
        app = InstallerApp(engine=self.engine, gum=FakeGum())
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(InstallError, "Wayland"):
                app.launch_shell()

    def test_blocked_nayori_does_not_offer_start_of_old_version(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        self.runner.fail = {"quickshell"}
        gum = FakeGum(confirmations=[False, True], choices=[["Пропустить"], ["Закрыть"]])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.components = {"nayori"}
        with patch("scripts.installer.ui.subprocess.Popen") as start:
            app.review()
        start.assert_not_called()
        result_menu = next(call for call in gum.calls if isinstance(call, tuple) and call[0] == "Результат установки")
        self.assertNotIn("Запустить Nayori", result_menu[1])

    def test_diagnostic_restore_requires_exact_confirmation(self):
        from scripts.installer.ui import InstallerApp

        self.engine.apply({"nayori"}, set())
        gum = FakeGum(choices=[["Откат"], ["Назад"]], inputs=["нет"])
        app = InstallerApp(engine=self.engine, gum=gum)
        app.diagnostics()
        self.assertTrue((self.paths.base / "current").is_symlink())


if __name__ == "__main__":
    unittest.main(verbosity=2)
