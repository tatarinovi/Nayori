"""Поиск лаунчера: файлы, команда списком аргументов, поколение запроса.

Не открывает сессию, не пишет в ~/.config и не запускает разобранные команды.
"""

import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "services/launcher/search_model.py"
WORKER_PATH = ROOT / "services/launcher/search_worker.py"
JS_PATH = ROOT / "services/launcher/SearchModel.js"

spec = importlib.util.spec_from_file_location("nayori_search_model", MODEL_PATH)
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)


class Clock:
    def __init__(self, expire_after):
        self.calls = 0
        self.expire_after = expire_after

    def __call__(self):
        self.calls += 1
        if self.calls > self.expire_after:
            return 10.0
        return 0.0


def tree(root: Path):
    (root / "notes.txt").write_text("notes", encoding="utf-8")
    (root / "Отчёт.txt").write_text("отчёт", encoding="utf-8")
    (root / ".bashrc-hidden").write_text("hidden", encoding="utf-8")
    docs = root / "Documents"
    docs.mkdir()
    (docs / "report.txt").write_text("report", encoding="utf-8")
    (docs / "my notes.txt").write_text("spaced", encoding="utf-8")
    git = root / ".git"
    git.mkdir()
    (git / "git-only-marker").write_text("secret", encoding="utf-8")
    modules = root / "node_modules" / "pkg"
    modules.mkdir(parents=True)
    (modules / "index.js").write_text("js", encoding="utf-8")
    cache = root / "cache"
    cache.mkdir()
    (cache / "blob.bin").write_text("blob", encoding="utf-8")
    pyc = root / "__pycache__"
    pyc.mkdir()
    (pyc / "mod.pyc").write_text("pyc", encoding="utf-8")
    hidden = root / ".config"
    hidden.mkdir()
    (hidden / "inside-hidden.txt").write_text("nope", encoding="utf-8")
    deep = root
    for name in ("a", "b", "c", "d", "e", "f", "g"):
        deep = deep / name
        deep.mkdir()
    (deep / "too-deep.txt").write_text("deep", encoding="utf-8")
    outside = root.parent / "outside-search"
    outside.mkdir()
    (outside / "escaped-marker.txt").write_text("out", encoding="utf-8")
    (root / "link-out").symlink_to(outside)
    locked = root / "locked"
    locked.mkdir()
    (locked / "visible-secret.txt").write_text("x", encoding="utf-8")
    return locked


class SearchModelTests(unittest.TestCase):
    def test_groups_labels_and_command_is_not_a_plain_query(self):
        rows = model.build_rows({
            "query": "firefox",
            "apps": [{"id": "firefox", "name": "Firefox", "genericName": "Browser", "iconSource": ""}],
            "files": [
                {"kind": "folder", "name": "firefox", "path": "/tmp/firefox", "directory": "~"},
                {"kind": "file", "name": "firefox.txt", "path": "/tmp/firefox.txt", "directory": "~/Documents"},
            ],
            "webTerms": "firefox",
            "webUrl": "https://www.google.com/search?q=firefox",
            "commandOk": True,
            "commandArgv": ["firefox"],
        })
        self.assertEqual([row["kind"] for row in rows], ["application", "folder", "file", "web"])
        self.assertEqual([row["typeLabel"] for row in rows], ["приложение", "папка", "файл", "интернет"])
        self.assertEqual(rows[0]["section"], "Приложения")
        self.assertEqual(rows[1]["section"], "Файлы")
        self.assertEqual(rows[2]["section"], "")
        self.assertEqual(rows[3]["section"], "")
        self.assertFalse(any(row["kind"] == "command" for row in rows))
        self.assertEqual(model.activation_plan(rows[0]), {"action": "desktop", "id": "firefox"})
        self.assertEqual(model.activation_plan(rows[2])["argv"], ["xdg-open", "/tmp/firefox.txt"])
        self.assertEqual(model.activation_plan(rows[3])["fallback"], ["xdg-open", rows[3]["url"]])
        self.assertNotIn("sh", model.activation_plan(rows[2])["argv"])

    def test_command_prefix_drops_other_rows_and_rejects_shell(self):
        plain = model.build_rows({"query": "echo hi", "commandOk": True, "commandArgv": ["echo", "hi"]})
        self.assertEqual(plain, [])
        waiting = model.build_rows({
            "query": ">echo hi",
            "apps": [{"id": "echo", "name": "Echo", "genericName": ""}],
            "files": [{"kind": "file", "name": "echo", "path": "/tmp/echo", "directory": "~"}],
            "webTerms": "echo",
            "webUrl": model.search_url("echo"),
            "commandPending": True,
        })
        self.assertEqual([row["kind"] for row in waiting], ["command"])
        self.assertTrue(waiting[0]["distinct"])
        self.assertEqual(waiting[0]["typeLabel"], "команда")
        self.assertEqual(waiting[0]["section"], "Команда")
        self.assertEqual(model.activation_plan(waiting[0])["action"], "wait")
        ready = model.command_argv("echo 'hello world'", "/home/tester")
        self.assertEqual(ready["argv"], ["echo", "hello world"])
        launched = model.build_rows({
            "query": ">echo 'hello world'",
            "commandOk": True,
            "commandArgv": ready["argv"],
        })
        self.assertEqual(model.activation_plan(launched[0]), {"action": "argv", "argv": ["echo", "hello world"]})
        for body in ("ls | wc", "ls && rm", "ls > out", "echo $(id)", "echo `id`", "ls ; id", "sh -c id", "/bin/bash -lc id"):
            parsed = model.command_argv(body, "/home/tester")
            self.assertFalse(parsed["ok"], body)
            self.assertEqual(parsed["argv"], [])
            plan = model.activation_plan({
                "kind": "command", "ok": True, "pending": False, "argv": ["sh", "-c", body],
            })
            self.assertEqual(plan["action"], "none")
        self.assertEqual(model.command_argv('echo "~"', "/home/tester")["argv"], ["echo", "~"])
        self.assertEqual(model.command_argv("echo ~/bin", "/home/tester")["argv"], ["echo", "/home/tester/bin"])
        self.assertEqual(model.command_argv(r"echo a\>b", "/home/tester")["argv"], ["echo", "a>b"])
        self.assertEqual(model.command_argv('echo ""', "/home/tester")["argv"], ["echo", ""])
        self.assertEqual(model.command_argv('echo "hi', "/home/tester")["code"], "quote")
        self.assertEqual(model.web_terms(">echo hi"), "")
        self.assertEqual(model.web_terms("web cats"), "cats")
        self.assertEqual(model.web_terms("WEB cats"), "cats")
        self.assertEqual(model.web_terms("web"), "")
        self.assertFalse(model.is_command_query("firefox"))
        self.assertTrue(model.is_command_query("  >firefox"))

    def test_keyboard_selection_keeps_a_pinned_row(self):
        rows = [
            {"key": "application:firefox"},
            {"key": "file:/tmp/a"},
            {"key": "web:q"},
        ]
        self.assertEqual(model.reconcile(rows, 2, "web:q", False)["index"], 0)
        pinned = model.move(rows, 0, 5)
        self.assertEqual(pinned, {"index": 2, "key": "web:q", "pinned": True})
        self.assertEqual(model.move(rows, 0, -3)["index"], 0)
        grown = [{"key": "file:/tmp/new"}] + rows
        kept = model.reconcile(grown, pinned["index"], pinned["key"], True)
        self.assertEqual(kept["key"], "web:q")
        self.assertEqual(kept["index"], 3)
        hovered = model.pin(rows, 1)
        self.assertTrue(hovered["pinned"])
        self.assertEqual(model.reconcile(grown, hovered["index"], hovered["key"], True)["key"], "file:/tmp/a")

    def test_stale_generation_empty_and_errors(self):
        self.assertFalse(model.result_is_current(2, {"generation": 1, "files": [{"path": "/tmp/old"}]}))
        self.assertTrue(model.result_is_current(2, {"generation": 2}))
        self.assertFalse(model.result_is_current(0, {"generation": 0}))
        self.assertFalse(model.result_is_current(True, {"generation": 1}))
        self.assertEqual(model.search_files("", [Path("/")], Path("/tmp"))["reason"], "short")
        self.assertEqual(model.search_files("a", [Path("/")], Path("/tmp"))["files"], [])
        failed = model.handle_request(
            {"generation": 7, "query": "notes"},
            {"HOME": "/tmp/nayori-missing-home"},
            clock=lambda: (_ for _ in ()).throw(RuntimeError("boom")),
        )
        self.assertEqual(failed["generation"], 7)
        self.assertEqual(failed["error"], "failed")
        self.assertEqual(failed["files"], [])
        self.assertFalse(model.result_is_current(8, failed))

    def test_file_walk_limits_and_missing_tools(self):
        with tempfile.TemporaryDirectory(prefix="nayori-search-") as temp:
            home = Path(temp) / "home"
            home.mkdir()
            locked = tree(home)
            found = model.search_files("report", [home], home)
            self.assertEqual([item["path"] for item in found["files"]], [str(home / "Documents" / "report.txt")])
            self.assertEqual(found["files"][0]["kind"], "file")
            self.assertEqual(found["files"][0]["directory"], "~/Documents")
            folded = model.search_files("отчёт", [home], home)
            self.assertEqual(folded["files"][0]["name"], "Отчёт.txt")
            self.assertTrue(any(item["name"] == ".bashrc-hidden" for item in model.search_files("bashrc-hidden", [home], home)["files"]))
            for query in ("git-only-marker", "index.js", "blob.bin", "mod.pyc", "inside-hidden", "escaped-marker", "too-deep"):
                self.assertEqual(model.search_files(query, [home], home)["files"], [], query)
            spaced = model.search_files("my notes", [home], home)
            self.assertEqual(spaced["files"][0]["path"], str(home / "Documents" / "my notes.txt"))
            self.assertEqual(model.open_argv(spaced["files"][0]["path"]), ["xdg-open", str(home / "Documents" / "my notes.txt")])
            clock = Clock(expire_after=2)
            partial = model.search_files("txt", [home], home, clock=clock)
            self.assertTrue(partial["truncated"])
            self.assertLess(len(partial["files"]), 8)
            os.chmod(locked, 0)
            try:
                hidden = model.search_files("visible-secret", [home], home)
                if os.geteuid() != 0:
                    self.assertEqual(hidden["files"], [])
            finally:
                os.chmod(locked, 0o700)
            def explode(*_args, **_kwargs):
                raise AssertionError("optional tool was executed")
            original_run = subprocess.run
            original_popen = subprocess.Popen
            subprocess.run = explode
            subprocess.Popen = explode
            try:
                still = model.search_files("report", [home], home)
                self.assertEqual(still["files"][0]["name"], "report.txt")
                report = model.optional_tools(which=lambda _name: None)
                self.assertFalse(report["used"])
                self.assertTrue(all(state == "missing" for state in report["tools"].values()))
                present = model.optional_tools(which=lambda _name: "/usr/bin/fd")
                self.assertFalse(present["used"])
                self.assertTrue(all(state == "installed" for state in present["tools"].values()))
            finally:
                subprocess.run = original_run
                subprocess.Popen = original_popen

    def test_roots_are_home_and_xdg_not_filesystem_root(self):
        with tempfile.TemporaryDirectory(prefix="nayori-roots-") as temp:
            base = Path(temp)
            home = base / "home"
            home.mkdir()
            external = base / "external-docs"
            external.mkdir()
            config = base / "config"
            config.mkdir()
            (config / "user-dirs.dirs").write_text(
                '\n'.join([
                    'XDG_DOCUMENTS_DIR="$HOME/Documents"',
                    f'XDG_DOWNLOAD_DIR="{external}"',
                    'XDG_DESKTOP_DIR="/"',
                    'XDG_MUSIC_DIR="$UNDEFINED/Music"',
                ]) + "\n",
                encoding="utf-8",
            )
            (home / "Documents").mkdir()
            env = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(config),
                "XDG_PICTURES_DIR": str(base / "pictures"),
            }
            (base / "pictures").mkdir()
            roots = model.collect_roots(home, env)
            resolved = [path.resolve() for path in roots]
            self.assertIn(home.resolve(), resolved)
            self.assertIn((home / "Documents").resolve(), resolved)
            self.assertIn(external.resolve(), resolved)
            self.assertIn((base / "pictures").resolve(), resolved)
            self.assertNotIn(Path("/"), resolved)
            self.assertLess(resolved.index(external.resolve()), resolved.index(home.resolve()))

    def test_worker_returns_argv_without_running_it(self):
        with tempfile.TemporaryDirectory(prefix="nayori-worker-") as temp:
            home = Path(temp) / "home"
            home.mkdir()
            (home / "readme.txt").write_text("hi", encoding="utf-8")
            sentinel = Path(temp) / "should-not-exist"
            env = dict(os.environ)
            env.update(HOME=str(home), XDG_CONFIG_HOME=str(Path(temp) / "config"),
                       XDG_CACHE_HOME=str(Path(temp) / "cache"), XDG_RUNTIME_DIR=temp)
            env.pop("NAYORI_LAUNCHER_SEARCH_ROOTS", None)

            def ask(payload):
                python = shutil.which("python3")
                self.assertTrue(python)
                done = subprocess.run(
                    [python, str(WORKER_PATH)],
                    input=json.dumps(payload, ensure_ascii=False) + "\n",
                    text=True, capture_output=True, env=env, timeout=10, cwd=temp,
                )
                self.assertEqual(done.returncode, 0, done.stderr)
                return json.loads(done.stdout)

            found = ask({"generation": 3, "query": "readme", "allowRoots": True, "roots": [str(home)]})
            self.assertTrue(model.result_is_current(3, found))
            self.assertEqual(found["files"][0]["path"], str(home / "readme.txt"))
            self.assertFalse(found["optionalToolsUsed"])
            command = ask({"generation": 4, "query": ">touch " + str(sentinel)})
            self.assertEqual(command["generation"], 4)
            self.assertEqual(command["files"], [])
            self.assertEqual(command["command"]["argv"], ["touch", str(sentinel)])
            self.assertFalse(sentinel.exists())
            stale = ask({"generation": 1, "query": "readme", "allowRoots": True, "roots": [str(home)]})
            self.assertFalse(model.result_is_current(4, stale))
            self.assertTrue(model.result_is_current(1, stale))

    def test_sources_do_not_shell_out_the_query(self):
        pieces = {
            "model": MODEL_PATH.read_text(encoding="utf-8"),
            "worker": WORKER_PATH.read_text(encoding="utf-8"),
            "js": JS_PATH.read_text(encoding="utf-8"),
            "launcher": (ROOT / "surfaces/launcher/Launcher.qml").read_text(encoding="utf-8"),
            "row": (ROOT / "surfaces/launcher/LauncherRow.qml").read_text(encoding="utf-8"),
            "search": (ROOT / "services/launcher/FileSearch.qml").read_text(encoding="utf-8"),
        }
        for name, text in pieces.items():
            self.assertIsNone(re.search(r"""["']sh["']\s*,\s*["']-c["']""", text), name)
        for name in ("launcher", "search", "js"):
            self.assertNotIn("sh -c", pieces[name], name)
        self.assertNotIn("subprocess", pieces["model"])
        self.assertNotIn("os.system", pieces["model"])
        self.assertIn('["xdg-open", path]', pieces["js"])
        self.assertIn('["xdg-open", url]', pieces["js"])
        self.assertIn("fileLaunch.command = plan.argv", pieces["launcher"])
        self.assertIn("webLaunch.command = plan.fallback", pieces["launcher"])
        self.assertIn("activationPlan", pieces["launcher"])
        self.assertIn("nativeScanCode === 45", pieces["launcher"])
        self.assertIn("resultIsCurrent", pieces["search"])
        self.assertIn("worker.running = false", pieces["search"])
        self.assertIn("onPositionChanged", pieces["row"])
        self.assertNotIn("onEntered", pieces["row"])
        self.assertNotIn("onEntered", pieces["launcher"])
        for label in ("приложение", "файл", "папка", "команда", "интернет", "Домашняя папка и каталоги XDG"):
            self.assertIn(label, pieces["js"])
        self.assertIn('kind === "command"', pieces["launcher"])


class InterfaceTests(unittest.TestCase):
    def test_qml_engine_and_static_focus_contract(self):
        if not shutil.which("qs"):
            self.skipTest("qs is not installed")
        with tempfile.TemporaryDirectory(prefix="nayori-launcher-smoke-") as temp:
            runtime = Path(temp) / "runtime"
            runtime.mkdir(mode=0o700)
            home = Path(temp) / "home"
            home.mkdir()
            env = dict(os.environ)
            for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "DISPLAY"):
                env.pop(key, None)
            env.update(
                QT_QPA_PLATFORM="offscreen",
                QT_QPA_PLATFORMTHEME="basic",
                QT_QUICK_BACKEND="software",
                QS_DISABLE_FILE_WATCHER="1",
                HOME=str(home),
                XDG_RUNTIME_DIR=str(runtime),
                XDG_CONFIG_HOME=str(home / ".config"),
                XDG_CACHE_HOME=str(home / ".cache"),
                XDG_DATA_HOME=str(home / ".local/share"),
                XDG_STATE_HOME=str(home / ".local/state"),
            )
            done = subprocess.run(
                ["qs", "-p", str(ROOT / "tests/smoke/LauncherSearchSmoke.qml"), "--no-color"],
                env=env, capture_output=True, text=True, timeout=20,
            )
            output = done.stdout + done.stderr
            self.assertEqual(done.returncode, 0, output)
            self.assertIn("LAUNCHER_SEARCH_SMOKE_PASS", output)
            for marker in ("ReferenceError", "TypeError", "Unable to assign", "Binding loop"):
                self.assertNotIn(marker, output)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    if result.wasSuccessful():
        print("LAUNCHER_SEARCH_TESTS_PASS")
    raise SystemExit(0 if result.wasSuccessful() else 1)
