"""UI-independent installer. All writes are explicit; importing is read-only."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import stat
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parents[2]
CATALOG = json.loads((Path(__file__).with_name("catalog.json")).read_text())


class InstallError(RuntimeError):
    pass


def exists(path):
    return path.exists() or path.is_symlink()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".metadata-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        sync_directory(path.parent)
    finally:
        if os.path.lexists(name):
            os.unlink(name)


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def sync_tree(root):
    if root.is_symlink():
        return
    if root.is_file():
        with root.open("rb") as stream:
            os.fsync(stream.fileno())
        return
    for path in root.rglob("*"):
        if not path.is_symlink() and path.is_file():
            with path.open("rb") as stream:
                os.fsync(stream.fileno())
    directories = [
        path for path in root.rglob("*") if not path.is_symlink() and path.is_dir()
    ]
    for path in sorted(directories, key=lambda path: len(path.parts), reverse=True):
        sync_directory(path)
    sync_directory(root)


def safe_directory(path):
    """Controlled paths may not redirect writes or be writable by other users."""
    if exists(path):
        mode = path.lstat()
        if (
            not stat.S_ISDIR(mode.st_mode)
            or mode.st_uid not in (0, os.getuid())
            or mode.st_mode & 0o022
        ):
            raise InstallError(f"Небезопасный каталог: {path}")


def checked_parents(path, base):
    current = path.parent
    while current != base.parent:
        safe_directory(current)
        if current == base:
            break
        current = current.parent


def inventory(root):
    """Do not follow links. Include content, link targets and permission bits."""
    result = {}
    if not exists(root):
        return result
    paths = [root]
    if root.is_dir() and not root.is_symlink():
        for parent, dirs, files in os.walk(root, followlinks=False):
            paths.extend(Path(parent) / name for name in dirs + files)
    for path in sorted(set(paths)):
        info = path.lstat()
        entry = {"mode": stat.S_IMODE(info.st_mode)}
        if stat.S_ISLNK(info.st_mode):
            entry.update(type="link", target=os.readlink(path))
        elif stat.S_ISREG(info.st_mode):
            entry.update(
                type="file", sha256=hashlib.sha256(path.read_bytes()).hexdigest()
            )
        elif stat.S_ISDIR(info.st_mode):
            entry.update(type="directory")
        else:
            raise InstallError(f"Неподдерживаемый тип файла: {path}")
        result["." if path == root else str(path.relative_to(root))] = entry
    return result


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif exists(path):
        path.unlink()


def validate_pam(path, controlled_root):
    checked_parents(path, controlled_root)
    before = path.lstat()
    if (
        not stat.S_ISREG(before.st_mode)
        or before.st_uid not in (0, os.getuid())
        or before.st_mode & 0o022
        or before.st_nlink != 1
    ):
        raise InstallError(f"Небезопасный PAM-профиль: {path}")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "r") as stream:
        opened = os.fstat(stream.fileno())
        text = stream.read()
        after = os.fstat(stream.fileno())

    def identity(info):
        return (
            info.st_dev,
            info.st_ino,
            info.st_mode,
            info.st_uid,
            info.st_gid,
            info.st_size,
            info.st_mtime_ns,
            info.st_ctime_ns,
        )

    if (
        identity(before) != identity(opened)
        or identity(opened) != identity(after)
        or identity(path.lstat()) != identity(after)
    ):
        raise InstallError("PAM-профиль изменился во время чтения")
    lines = [
        " ".join(line.split())
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if lines != ["auth required pam_unix.so"]:
        raise InstallError(
            "Разрешён только комплектный PAM-профиль: auth required pam_unix.so"
        )
    return text


def resolve_components(selected, catalog=CATALOG):
    chosen = set(selected)
    if chosen - catalog["components"].keys():
        raise InstallError("Неизвестный компонент")
    pending = list(chosen)
    while pending:
        key = pending.pop()
        for dependency in catalog["components"][key]["requires"]:
            if dependency not in catalog["components"]:
                raise InstallError(f"Неизвестная зависимость: {dependency}")
            if dependency not in chosen:
                chosen.add(dependency)
                pending.append(dependency)
    for key in chosen:
        conflicts = chosen.intersection(catalog["components"][key]["conflicts"])
        if conflicts:
            raise InstallError(f"{key}: несовместимо с {', '.join(sorted(conflicts))}")
    return chosen


def deselect_component(selected, key):
    chosen = set(selected) - {key}
    while True:
        invalid = {
            item
            for item in chosen
            if not set(CATALOG["components"][item]["requires"]) <= chosen
        }
        if not invalid:
            return chosen
        chosen -= invalid


class Paths:
    def __init__(self, env=None):
        env = os.environ if env is None else env
        home = Path(env.get("HOME", str(Path.home()))).absolute()
        self.data = Path(
            env.get("XDG_DATA_HOME", str(home / ".local/share"))
        ).absolute()
        self.config = Path(env.get("XDG_CONFIG_HOME", str(home / ".config"))).absolute()
        self.state = (
            Path(env.get("XDG_STATE_HOME", str(home / ".local/state"))).absolute()
            / "nayori/installer"
        )
        self.base = self.data / "nayori"
        self.niri = self.config / "niri"
        self.bin = home / ".local/bin"
        self.applications = self.data / "applications"


class Runner:
    def __init__(self, interactive=None):
        self.interactive = interactive or self._interactive

    @staticmethod
    def _interactive(argv):
        return subprocess.call(argv)

    def capture(self, argv):
        try:
            proc = subprocess.run(
                argv,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=45,
            )
            return proc.returncode, proc.stdout.strip()
        except (OSError, subprocess.TimeoutExpired) as error:
            return 127, str(error)

    def run(self, argv):
        return self.interactive(argv)

    def helper(self):
        return shutil.which("paru") or shutil.which("yay")


class Transaction:
    """Write-ahead rename journal; recovery is idempotent after every rename."""

    def __init__(self, paths, kind="install", record=None):
        self.paths = paths
        self.file = paths.state / "transaction.json"
        self.record = record or {
            "schema_version": 1,
            "id": uuid.uuid4().hex,
            "kind": kind,
            "status": "pending",
            "operations": [],
        }

    def save(self):
        atomic_json(self.file, self.record)

    def replace(self, destination, staged):
        destination = Path(destination)
        staged = Path(staged)
        sync_tree(staged)
        backup = destination.with_name(
            f".{destination.name}.nayori-backup-{self.record['id']}"
        )
        if exists(backup):
            raise InstallError(f"Резервная копия уже существует: {backup}")
        operation = {
            "destination": str(destination),
            "backup": str(backup),
            "staged": str(staged),
            "before": inventory(destination),
            "after": inventory(staged),
            "phase": "prepared",
        }
        self.record["operations"].append(operation)
        self.save()
        if destination.is_symlink() and staged.is_symlink():
            # Copy the old pointer, then replace current in ONE rename (no missing-current window).
            backup.symlink_to(os.readlink(destination))
        elif exists(destination):
            os.replace(destination, backup)
        sync_directory(destination.parent)
        operation["phase"] = "backed-up"
        self.save()
        os.replace(staged, destination)
        sync_directory(destination.parent)
        operation["phase"] = "installed"
        self.save()

    def restore(self, allow_modified=False):
        # Validate all targets before touching any, so conflicts never cause a partial rollback.
        for op in reversed(self.record["operations"]):
            dest, backup, staged = map(
                Path, (op["destination"], op["backup"], op["staged"])
            )
            if op["phase"] == "restored" or (
                op["before"] and not exists(backup) and inventory(dest) == op["before"]
            ):
                continue
            installed = op["phase"] == "installed" or (
                not exists(staged) and inventory(dest) == op["after"]
            )
            if installed and inventory(dest) != op["after"] and not allow_modified:
                raise InstallError(
                    f"После установки изменён {dest}; для восстановления нужно подтвердить сохранение правок."
                )
            if op["before"] and exists(backup) and inventory(backup) != op["before"]:
                raise InstallError(f"Резервная копия изменена: {backup}")
        for op in reversed(self.record["operations"]):
            if op["phase"] == "restored":
                continue
            dest, backup, staged = map(
                Path, (op["destination"], op["backup"], op["staged"])
            )
            if op["before"] and not exists(backup) and inventory(dest) == op["before"]:
                op["phase"] = "restored"
                self.save()
                continue
            if exists(backup):
                if exists(dest):
                    # Preserve post-install changes, also across a recovery crash.
                    saved = dest.with_name(
                        f".{dest.name}.nayori-displaced-{self.record['id']}"
                    )
                    if exists(saved):
                        raise InstallError(f"Конфликт восстановления: {saved}")
                    os.replace(dest, saved)
                    op["displaced"] = str(saved)
                    self.save()
                os.replace(backup, dest)
            elif not op["before"] and not exists(staged) and exists(dest):
                saved = dest.with_name(
                    f".{dest.name}.nayori-displaced-{self.record['id']}"
                )
                os.replace(dest, saved)
                op["displaced"] = str(saved)
            elif op["before"] and inventory(dest) != op["before"]:
                raise InstallError(f"Нет исходного файла для восстановления: {dest}")
            remove(staged)
            sync_directory(dest.parent)
            op["phase"] = "restored"
            self.save()
        self.record["status"] = "restored"
        self.save()

    def commit(self):
        self.record["status"] = "committed"
        self.save()
        atomic_json(self.paths.state / "last-install.json", self.record)


class Engine:
    def __init__(self, paths=None, runner=None, source=REPO, log=None):
        self.paths = paths or Paths()
        self.runner = runner or Runner()
        self.source = Path(source)
        self.log = log or (lambda text: None)
        self.cancelled = False

    def selected_packages(self, components, apps):
        chosen = resolve_components(components)
        if set(apps) - CATALOG["apps"].keys():
            raise InstallError("Неизвестное приложение")
        packages = {}
        for key in sorted(chosen):
            for package in CATALOG["components"][key]["packages"]:
                source = (
                    CATALOG["components"][key]
                    .get("package_sources", {})
                    .get(package, "repo")
                )
                packages.setdefault(package, {"source": source, "owners": []})[
                    "owners"
                ].append(key)
        for key in sorted(apps):
            app = CATALOG["apps"][key]
            for package in app["packages"]:
                packages.setdefault(package, {"source": app["source"], "owners": []})[
                    "owners"
                ].append("app:" + key)
        return chosen, packages

    def preflight(self, components, apps):
        chosen, packages = self.selected_packages(components, apps)
        problems = []
        for package, item in packages.items():
            installed = self.runner.capture(["pacman", "-Q", package])[0] == 0
            item["installed"] = installed
            item["available"] = installed
            if not installed:
                cmd = (
                    ["pacman", "-Si", package]
                    if item["source"] == "repo"
                    else [self.runner.helper() or "false", "-Si", "--aur", package]
                )
                code, output = self.runner.capture(cmd)
                item["available"] = code == 0
                if code:
                    problems.append(f"{package}: недоступен ({output[:160]})")
        if "lock" in chosen:
            try:
                validate_pam(self.source / "pam/nayori-lock", self.source)
            except (OSError, InstallError) as error:
                problems.append(str(error))
        blocked_components = {}
        for key in chosen:
            for package in CATALOG["components"][key].get("incompatible_packages", []):
                if self.runner.capture(["pacman", "-Q", package])[0] == 0:
                    message = f"{key}: конфликт с установленным {package}"
                    problems.append(message)
                    blocked_components[key] = message
        affected_paths = [str(self.paths.state)]
        if "nayori" in chosen:
            affected_paths.extend(
                [
                    str(self.paths.base),
                    str(self.paths.bin / "nayori"),
                    str(self.paths.applications / "nayori.desktop"),
                ]
            )
        if "niri" in chosen:
            affected_paths.append(str(self.paths.niri))
        changes = self.modified_files()
        return {
            "components": sorted(chosen),
            "apps": sorted(apps),
            "packages": packages,
            "problems": problems,
            "blocked_components": blocked_components,
            "modified": changes,
            "paths": affected_paths,
        }

    def modified_files(self):
        problems = []
        installed = self.paths.state / "installed.json"
        if installed.is_file():
            for name, expected in (
                json.loads(installed.read_text()).get("external_files", {}).items()
            ):
                if inventory(Path(name)) != expected:
                    problems.append(name)
        state = self.paths.state / "last-install.json"
        if state.is_file():
            record = json.loads(state.read_text())
            if record["status"] == "committed":
                for op in record["operations"]:
                    if inventory(Path(op["destination"])) != op["after"]:
                        problems.append(op["destination"])
        current = self.paths.base / "current"
        if current.is_symlink():
            root = current.resolve()
            manifest = root / "manifest.json"
            if manifest.is_file():
                expected = json.loads(manifest.read_text())["files"]
                actual = inventory(root)
                actual.pop("manifest.json", None)
                if actual != expected:
                    problems.append(str(root))
        return sorted(set(problems))

    def ensure_writable(self):
        safe_directory(self.paths.base)
        current = self.paths.base / "current"
        if exists(current) and (
            not current.is_symlink()
            or not current.resolve().is_relative_to(self.paths.base / "releases")
        ):
            raise InstallError("Небезопасный указатель активной версии")
        for path in (
            self.paths.base,
            self.paths.state,
            self.paths.niri,
            self.paths.bin / "nayori",
            self.paths.applications / "nayori.desktop",
        ):
            # niri itself may be a link: it is backed up, never traversed.
            for ancestor in reversed(path.parents):
                if ancestor == Path("/") or ancestor == Path("/tmp"):
                    continue
                safe_directory(ancestor)
        self.paths.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        safe_directory(self.paths.state)

    def lock(self):
        self.ensure_writable()
        fd = os.open(
            self.paths.state / "installer.lock",
            os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW,
            0o600,
        )
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(fd)
            raise InstallError("Другой установщик уже работает") from None
        return fd

    def pending(self):
        path = self.paths.state / "transaction.json"
        if path.is_file():
            record = json.loads(path.read_text())
            if record["status"] == "pending":
                return record
        return None

    def restore(self, allow_modified=False, rollback=False):
        fd = self.lock()
        try:
            record = self.pending()
            if record is None and rollback:
                file = self.paths.state / "last-install.json"
                if file.is_file():
                    record = json.loads(file.read_text())
                    if record["status"] != "committed":
                        record = None
            if not record:
                raise InstallError("Нет операции для восстановления")
            if record.get("system_transaction"):
                code = self.runner.run(
                    [
                        "sudo",
                        "python3",
                        str(self.source / "scripts/install-sddm.py"),
                        "--rollback",
                        record["id"],
                    ]
                )
                if code:
                    raise InstallError(
                        "Не удалось восстановить SDDM; пользовательские файлы пока не изменены"
                    )
            transaction = Transaction(self.paths, record=record)
            transaction.restore(allow_modified)
            atomic_json(self.paths.state / "last-install.json", transaction.record)
            self.log("Исходные файлы восстановлены. Пакеты не удалялись.")
        finally:
            os.close(fd)

    def _copy_release(self, components):
        self.paths.base.mkdir(parents=True, exist_ok=True)
        releases = self.paths.base / "releases"
        safe_directory(releases)
        releases.mkdir(exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".staging-", dir=releases))
        try:
            include = [
                "shell.qml",
                "tokens",
                "services",
                "surfaces",
                "islands",
                "assets",
                "pam",
                "scripts",
            ]
            include += [
                name
                for name in ("configs", "sddm", "install.sh")
                if exists(self.source / name)
            ]
            for name in include:
                src, dest = self.source / name, stage / name
                if src.is_dir():
                    # Do not follow source links while copying.
                    shutil.copytree(
                        src,
                        dest,
                        symlinks=True,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
                    )
                else:
                    shutil.copy2(src, dest, follow_symlinks=False)
            for path in stage.rglob("*"):
                info = path.lstat()
                if info.st_uid not in (0, os.getuid()) or info.st_mode & 0o022:
                    raise InstallError(f"Запись для группы/остальных: {path}")
                if path.is_symlink() and (
                    os.path.isabs(os.readlink(path))
                    or not path.resolve().is_relative_to(stage)
                ):
                    raise InstallError(f"Ссылка вне версии: {path}")
            # Always verify PAM: LockService loads it even when not selected in this run.
            original = validate_pam(self.source / "pam/nayori-lock", self.source)
            if validate_pam(stage / "pam/nayori-lock", stage) != original:
                raise InstallError("PAM изменился при копировании")
            expected = inventory(stage)
            for name in include:
                actual = {
                    k: v
                    for k, v in expected.items()
                    if k == name or k.startswith(name + "/")
                }
                source_inventory = inventory(self.source / name)
                source_inventory = {
                    name if k == "." else f"{name}/{k}": v
                    for k, v in source_inventory.items()
                    if "__pycache__" not in Path(k).parts and not k.endswith(".pyc")
                }
                if actual != source_inventory:
                    raise InstallError(f"Копия не совпадает с источником: {name}")
            code, commit = self.runner.capture(
                ["git", "-C", str(self.source), "rev-parse", "HEAD"]
            )
            dirty_code, dirty = self.runner.capture(
                ["git", "-C", str(self.source), "status", "--porcelain", "--untracked-files=all"]
            )
            if dirty_code or dirty:
                commit = "unknown"
            version = (
                datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                + "-"
                + uuid.uuid4().hex[:10]
            )
            manifest = {
                "schema_version": 1,
                "version": version,
                "commit": commit if not code else "unknown",
                "components": sorted(components),
                "files": expected,
            }
            atomic_json(stage / "manifest.json", manifest)
            # Verify persisted content before publishing; files are flushed before the pointer switch.
            if {
                k: v for k, v in inventory(stage).items() if k != "manifest.json"
            } != expected:
                raise InstallError("Контрольные суммы версии не совпадают")
            sync_tree(stage)
            destination = releases / version
            os.replace(stage, destination)
            sync_directory(releases)
            return destination
        finally:
            if stage.exists():
                shutil.rmtree(stage)

    def _file(self, transaction, destination, contents, mode=0o644):
        destination.parent.mkdir(parents=True, exist_ok=True)
        fd, name = tempfile.mkstemp(prefix=".nayori-stage-", dir=destination.parent)
        with os.fdopen(fd, "w") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        staged = Path(name)
        staged.chmod(mode)
        transaction.replace(destination, staged)

    def _niri(self, transaction, components):
        self.paths.config.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".niri-staging-", dir=self.paths.config))
        try:
            shutil.copytree(
                self.source / "configs/niri", stage, dirs_exist_ok=True, symlinks=True
            )
            launcher = str(self.paths.bin / "nayori")
            if any(c in launcher for c in ("\n", "\r", "\x00")):
                raise InstallError("Недопустимый путь launcher")
            command = json.dumps(launcher, ensure_ascii=False)
            bindings = []
            if "nayori" in components:
                bindings.append(
                    f'Alt+Space {{ spawn {command} "ipc" "launcher" "toggle"; }}'
                )
            for component, key, target, method in [
                ("clipboard", "Mod+V", "clipboard", "toggle"),
                ("lock", "Mod+L", "lock", "lock"),
                ("capture", "Print", "capture", "screenshot"),
                ("capture", "Alt+Print", "capture", "record"),
            ]:
                if component in components:
                    bindings.append(
                        f'{key} {{ spawn {command} "ipc" "{target}" "{method}"; }}'
                    )
            keybinds = stage / "cfg/keybinds.kdl"
            keybinds.write_text(
                keybinds.read_text().replace(
                    "// NAYORI_BINDINGS", "\n    ".join(bindings)
                )
            )
            if "autostart" in components:
                (stage / "cfg/autostart.kdl").write_text(
                    f"spawn-at-startup {command}\n"
                )
            for path in stage.rglob("*"):
                if path.is_symlink():
                    raise InstallError(f"Симлинки в комплекте niri запрещены: {path}")
                if path.is_file():
                    content = path.read_text()
                    if re.search(
                        r'/(?:home|Users)/[^/\s"]+',
                        content.replace(launcher, "LAUNCHER"),
                    ):
                        raise InstallError(f"Личный абсолютный путь: {path}")
                    for include in re.findall(
                        r'^\s*include\s+"([^"]+)"', content, re.M
                    ):
                        target = path.parent / include
                        if (
                            not target.resolve().is_relative_to(stage)
                            or not target.is_file()
                        ):
                            raise InstallError(f"Недопустимый include: {include}")
            code, output = self.runner.capture(
                ["niri", "validate", "-c", str(stage / "config.kdl")]
            )
            if code:
                raise InstallError(f"Конфигурация niri отклонена:\n{output}")
            transaction.replace(self.paths.niri, stage)
        finally:
            if stage.exists():
                shutil.rmtree(stage)

    def apply(
        self,
        components,
        apps,
        *,
        allow_modified=False,
        update=False,
        on_package_error=None,
    ):
        fd = self.lock()
        tx = None
        log_stream = None
        previous_log = self.log
        try:
            if self.pending():
                raise InstallError(
                    "Есть незавершённая транзакция. Сначала выполните восстановление."
                )
            plan = self.preflight(components, apps)
            if plan["modified"] and not allow_modified:
                raise InstallError(
                    "Есть пользовательские изменения; требуется явное согласие на бэкап и замену"
                )
            components = set(plan["components"])
            if "nayori" in components:
                validate_pam(self.source / "pam/nayori-lock", self.source)
            self.paths.state.mkdir(parents=True, exist_ok=True)
            log_path = self.paths.state / (
                datetime.now().strftime("%Y%m%d-%H%M%S-")
                + uuid.uuid4().hex[:8]
                + ".log"
            )
            log_stream = log_path.open("w")

            def log(message):
                log_stream.write(message + "\n")
                log_stream.flush()
                previous_log(message)

            self.log = log
            self.log(f"Журнал: {log_path}")
            blocked = set(plan["blocked_components"])

            def block_dependents():
                while True:
                    dependents = {
                        key
                        for key in components
                        if set(CATALOG["components"][key]["requires"]) & blocked
                    }
                    if dependents <= blocked:
                        return
                    blocked.update(dependents)

            for package, item in plan["packages"].items():
                if not item["available"]:
                    blocked.update(item["owners"])
                    self.log(f"ПРОПУСК {package}: недоступен")
            block_dependents()
            if update and not self.cancelled:
                if self.runner.run(["sudo", "pacman", "-Syu"]):
                    raise InstallError("Обновление системы не завершено")
            for package, item in plan["packages"].items():
                if self.cancelled:
                    raise InstallError(
                        "Отменено после завершения текущей пакетной операции"
                    )
                if (
                    item["installed"]
                    or not item["available"]
                    or set(item["owners"]) <= blocked
                ):
                    continue
                argv = (
                    ["sudo", "pacman", "-S", "--needed", package]
                    if item["source"] == "repo"
                    else [self.runner.helper(), "-S", "--needed", "--aur", package]
                )
                while True:
                    self.log("Пакет: " + package)
                    self.log("КОМАНДА: " + shlex.join(argv))
                    if not self.runner.run(argv):
                        self.log("УСПЕХ " + package)
                        break
                    action = on_package_error(package) if on_package_error else "skip"
                    if action == "retry":
                        continue
                    if action == "cancel":
                        raise InstallError("Установка остановлена после ошибки пакета")
                    blocked.update(item["owners"])
                    block_dependents()
                    self.log("ОШИБКА / ПРОПУСК " + package)
                    break
            active = components - blocked
            while True:
                reduced = {
                    key
                    for key in active
                    if set(CATALOG["components"][key]["requires"]) <= active
                }
                if reduced == active:
                    break
                active = reduced
            for key in sorted(components - active):
                self.log("ЗАБЛОКИРОВАН компонент: " + key)
            if self.cancelled:
                raise InstallError("Отменено до применения файлов")
            tx = Transaction(self.paths)
            tx.record["components"] = sorted(active)
            tx.record["apps"] = sorted(
                set(apps) - {key[4:] for key in blocked if key.startswith("app:")}
            )
            tx.record["packages"] = list(plan["packages"])
            tx.save()
            if "nayori" in active:
                # A pre-versioned installation is replaced as a whole, retaining its directory backup.
                legacy = (self.paths.base / "shell.qml").is_file() and not exists(
                    self.paths.base / "current"
                )
                if legacy:
                    original_base = self.paths.base
                    temporary_base = Path(
                        tempfile.mkdtemp(
                            prefix=".nayori-migration-", dir=original_base.parent
                        )
                    )
                    try:
                        self.paths.base = temporary_base
                        staged_release = self._copy_release(active)
                        (temporary_base / "current").symlink_to(
                            staged_release.relative_to(temporary_base)
                        )
                    finally:
                        self.paths.base = original_base
                    tx.replace(original_base, temporary_base)
                    release = original_base / "releases" / staged_release.name
                else:
                    release = self._copy_release(active)
                pointer = self.paths.base / (".current-" + tx.record["id"])
                if not legacy:
                    pointer.symlink_to(release.relative_to(self.paths.base))
                    tx.replace(self.paths.base / "current", pointer)
                # The stable launcher is independent of individual versions.
                launcher = (self.source / "scripts/installer/launcher.py").read_text()
                launcher = launcher.replace(
                    "INSTALL_BASE = None",
                    "INSTALL_BASE = " + repr(str(self.paths.base)),
                )
                self._file(tx, self.paths.bin / "nayori", launcher, 0o755)
                # Desktop Exec quoting differs from shell quoting.
                quoted = (
                    str(self.paths.bin / "nayori")
                    .replace("\\", "\\\\")
                    .replace('"', '\\"')
                    .replace("`", "\\`")
                    .replace("$", "\\$")
                    .replace("%", "%%")
                )
                self._file(
                    tx,
                    self.paths.applications / "nayori.desktop",
                    '[Desktop Entry]\nType=Application\nName=Nayori\nExec="'
                    + quoted
                    + '"\nTerminal=false\nCategories=System;\n',
                )
            if "niri" in active:
                self._niri(tx, active)
            if "sddm" in active:
                tx.record["system_transaction"] = True
                tx.save()
                args = [
                    "sudo",
                    "python3",
                    str(self.source / "scripts/install-sddm.py"),
                    "--owner",
                    str(os.getuid()),
                    "--transaction",
                    tx.record["id"],
                ]
                if "sddm-select" in active:
                    args.append("--select-theme")
                if self.runner.run(args):
                    raise InstallError(
                        "Установка SDDM не завершена; требуется восстановление"
                    )
            installed_file = self.paths.state / "installed.json"
            installed = (
                json.loads(installed_file.read_text())
                if installed_file.is_file()
                else {"schema_version": 1, "external_files": {}, "components": []}
            )
            installed["previous_version"] = installed.get("active_version")
            if "nayori" in active:
                installed["active_version"] = release.name
                installed["components"] = sorted(active)
            else:
                installed["components"] = sorted(set(installed["components"]) | active)
            installed["transaction"] = tx.record["id"]
            for op in tx.record["operations"]:
                installed["external_files"][op["destination"]] = op["after"]
            self._file(
                tx,
                installed_file,
                json.dumps(installed, ensure_ascii=False, indent=2) + "\n",
                0o600,
            )
            tx.commit()
            self.log("УСПЕХ: выбранные доступные компоненты установлены.")
            if blocked:
                self.log(
                    "Есть пропуски. См. список пакетов и заблокированных компонентов выше."
                )
            if "autostart" in active and "niri" not in active:
                self.log(
                    "Добавьте в niri вручную: spawn-at-startup "
                    + json.dumps(str(self.paths.bin / "nayori"))
                )
            requirements = {
                requirement
                for key in active
                for requirement in CATALOG["components"][key]["system_requirements"]
            }
            for service in sorted(requirements - {"session-bus", "notification-owner"}):
                user_service = service.startswith("pipewire")
                command = [
                    "systemctl",
                    *(["--user"] if user_service else []),
                    "is-active",
                    service,
                ]
                if self.runner.capture(command)[0]:
                    manual = (
                        ("systemctl --user" if user_service else "sudo systemctl")
                        + " enable --now "
                        + service
                    )
                    self.log(
                        f"ПРЕДУПРЕЖДЕНИЕ: {service} не активна. При необходимости выполните вручную: {manual}"
                    )
            if "notifications" in active:
                code, owner = self.runner.capture(
                    ["busctl", "--user", "status", "org.freedesktop.Notifications"]
                )
                if not code:
                    self.log(
                        "ПРЕДУПРЕЖДЕНИЕ: сервис уведомлений уже занят. Владелец автоматически не останавливается."
                    )
            self.log("Службы не переключались. Работающая оболочка не перезапускалась.")
            return tx.record
        except Exception:
            if tx and not tx.record.get("system_transaction"):
                try:
                    tx.restore()
                except Exception as error:
                    self.log("Требуется восстановление: " + str(error))
            raise
        finally:
            self.log = previous_log
            if log_stream:
                log_stream.close()
            os.close(fd)

    def diagnose(self):
        report = []

        def add(status, title, detail):
            report.append({"status": status, "title": title, "detail": detail})

        try:
            pending = self.pending()
            add(
                "ошибка" if pending else "исправно",
                "Транзакция",
                "Требуется восстановление" if pending else "Нет незавершённых операций",
            )
            current = self.paths.base / "current"
            if current.is_symlink() and current.resolve().is_dir():
                release = current.resolve()
                manifest = json.loads((release / "manifest.json").read_text())
                add("исправно", "Версия", manifest["version"])
                changes = self.modified_files()
                add(
                    "предупреждение" if changes else "исправно",
                    "Целостность",
                    "\n".join(changes) or "Файлы совпадают с манифестом",
                )
                try:
                    validate_pam(release / "pam/nayori-lock", release)
                    add(
                        "исправно",
                        "PAM: статическая проверка",
                        "Права и содержимое допустимы; аутентификация не проверялась",
                    )
                except (OSError, InstallError) as error:
                    add("ошибка", "PAM", str(error))
                _, packages = self.selected_packages(manifest["components"], [])
                for package in packages:
                    code, output = self.runner.capture(["pacman", "-Q", package])
                    add(
                        "предупреждение" if code else "исправно",
                        "Пакет " + package,
                        output,
                    )
            else:
                add("не проверено", "Версия", "Установленная версия Nayori не найдена")
            if self.paths.niri.is_dir():
                code, output = self.runner.capture(
                    ["niri", "validate", "-c", str(self.paths.niri / "config.kdl")]
                )
                add("ошибка" if code else "исправно", "niri", output)
            else:
                add("не проверено", "niri", "Конфигурация отсутствует")
            for service in ("NetworkManager", "bluetooth", "upower", "sddm"):
                code, output = self.runner.capture(["systemctl", "is-active", service])
                add("предупреждение" if code else "исправно", service, output)
            for service in ("pipewire", "pipewire-pulse"):
                code, output = self.runner.capture(
                    ["systemctl", "--user", "is-active", service]
                )
                add("предупреждение" if code else "исправно", service, output)
            launcher = self.paths.bin / "nayori"
            if launcher.is_file():
                code, output = self.runner.capture([str(launcher), "status"])
                add("предупреждение" if code else "исправно", "IPC", output)
            else:
                add("не проверено", "IPC", "Launcher не установлен")
            code, output = self.runner.capture(
                ["busctl", "--user", "status", "org.freedesktop.Notifications"]
            )
            add(
                "предупреждение" if not code else "не проверено",
                "Уведомления",
                output[:500] if not code else "Владелец D-Bus не найден",
            )
        except (OSError, ValueError, KeyError, InstallError) as error:
            add("ошибка", "Диагностика", str(error))
        return report
