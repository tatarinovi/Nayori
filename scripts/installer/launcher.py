#!/usr/bin/env python3
"""Installed as ~/.local/bin/nayori. Runtime metadata pins IPC to the live release."""

import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

INSTALL_BASE = None  # Replaced by the installer, never inferred from a mutable CWD.


def update_release(base, options):
    if options not in ([], ["--check"]):
        raise RuntimeError("Использование: nayori update [--check]")
    release = (base / "current").resolve(strict=True)
    if release.parent != (base / "releases").resolve():
        raise RuntimeError("Некорректный указатель установленной версии")
    script = release / "scripts/nayori-update.py"
    if not (release / "manifest.json").is_file() or not script.is_file():
        raise RuntimeError("В установленной версии нет updater Nayori")

    def request(operation, *arguments):
        result = subprocess.run(
            [sys.executable, str(script), operation, *arguments],
            capture_output=True, text=True,
        )
        try:
            reply = json.loads(result.stdout)
        except ValueError:
            raise RuntimeError(result.stderr.strip() or "Updater вернул некорректный ответ") from None
        if not isinstance(reply, dict) or not reply.get("ok") or result.returncode:
            message = reply.get("error") if isinstance(reply, dict) else None
            raise RuntimeError(message or result.stderr.strip() or "Не удалось обновить Nayori")
        if reply.get("installed") is not True:
            raise RuntimeError("Установленная версия Nayori не найдена")
        return reply

    checked = request("check")
    if not checked.get("available"):
        print("Nayori уже обновлена.")
        return 0
    latest = checked.get("latest")
    if not isinstance(latest, str) or len(latest) != 40 or any(c not in "0123456789abcdef" for c in latest):
        raise RuntimeError("Updater вернул некорректный идентификатор версии")
    if options == ["--check"]:
        print("Доступно обновление Nayori: " + latest[:12])
        return 0
    print("Устанавливаем обновление Nayori…", flush=True)
    applied = request("apply", latest)
    print(applied.get("message") or "Обновление установлено. Перезапустите Nayori.")
    return 0


def main():
    base = Path(INSTALL_BASE)
    args = sys.argv[1:]
    if args and args[0] == "update":
        return update_release(base, args[1:])
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "nayori"
    if args and args[0] in ("ipc", "status", "settings", "-stop"):
        if args[0] == "-stop" and len(args) != 1:
            raise RuntimeError("Использование: nayori -stop")
        record = json.loads((runtime / "active.json").read_text())
        # PID reuse cannot accidentally address a different process.
        pid = record["pid"]
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            raise RuntimeError("Неверный PID работающей версии")
        pidfd = os.pidfd_open(pid) if args[0] == "-stop" else None
        try:
            start = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]
            if start != record["start"]:
                raise RuntimeError("Запись работающей версии устарела")
            release = record["release"]
            if not Path(release).is_relative_to(base / "releases"):
                raise RuntimeError("Неверная запись работающей версии")
            if pidfd is not None:
                signal.pidfd_send_signal(pidfd, signal.SIGTERM)
                return 0
        finally:
            if pidfd is not None:
                os.close(pidfd)
        if args[0] == "status":
            command = ["qs", "ipc", "-p", release, "show"]
        elif args[0] == "settings":
            command = ["qs", "ipc", "-p", release, "call", "settings", "open"]
        else:
            command = ["qs", "ipc", "-p", release, "call", *args[1:]]
        return subprocess.call(command)
    if args:
        raise RuntimeError(
            "Использование: nayori [update [--check] | ipc TARGET METHOD [ARGS...] | settings | status | -stop]"
        )
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = runtime.lstat()
    if runtime.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise RuntimeError("Небезопасный каталог runtime")
    fd = os.open(
        runtime / "instance.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600
    )
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        raise RuntimeError("Nayori уже запущена через launcher") from None
    try:
        # An unexpectedly killed launcher can leave its shell running unlocked.
        try:
            record = json.loads((runtime / "active.json").read_text())
            pid = record["pid"]
            start = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]
            if start == record["start"]:
                raise RuntimeError("Nayori уже запущена через launcher")
        except FileNotFoundError:
            pass
        release = (base / "current").resolve(strict=True)
        if not release.is_relative_to(base / "releases"):
            raise RuntimeError("Активная версия вне releases")
        manifest = json.loads((release / "manifest.json").read_text())
        env = os.environ.copy()
        env["NAYORI_NOTIFICATIONS"] = (
            "1" if "notifications" in manifest["components"] else "0"
        )
        # Do not leak the lock through Quickshell into applications it starts.
        process = subprocess.Popen(["qs", "-p", str(release), "--no-duplicate"], env=env)
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(
                signum,
                lambda number, frame: (
                    process.send_signal(number) if process.poll() is None else None
                ),
            )
        try:
            start = (
                Path(f"/proc/{process.pid}/stat")
                .read_text()
                .rsplit(")", 1)[1]
                .split()[19]
            )
            record = {"pid": process.pid, "start": start, "release": str(release)}
            handle, name = tempfile.mkstemp(dir=runtime, prefix=".active-")
            with os.fdopen(handle, "w") as stream:
                json.dump(record, stream)
            os.replace(name, runtime / "active.json")
            return process.wait()
        finally:
            (runtime / "active.json").unlink(missing_ok=True)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f"Nayori: {error}", file=sys.stderr)
        sys.exit(1)
