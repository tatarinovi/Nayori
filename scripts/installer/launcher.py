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


def main():
    base = Path(INSTALL_BASE)
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "nayori"
    args = sys.argv[1:]
    if args and args[0] in ("ipc", "status", "settings"):
        record = json.loads((runtime / "active.json").read_text())
        # PID reuse cannot accidentally address a different process.
        pid = record["pid"]
        start = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]
        if start != record["start"]:
            raise RuntimeError("Запись работающей версии устарела")
        release = record["release"]
        if not Path(release).is_relative_to(base / "releases"):
            raise RuntimeError("Неверная запись работающей версии")
        if args[0] == "status":
            command = ["qs", "ipc", "-p", release, "show"]
        elif args[0] == "settings":
            command = ["qs", "ipc", "-p", release, "call", "settings", "open"]
        else:
            command = ["qs", "ipc", "-p", release, "call", *args[1:]]
        return subprocess.call(command)
    if args:
        raise RuntimeError(
            "Использование: nayori [ipc TARGET METHOD [ARGS...] | settings | status]"
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
        release = (base / "current").resolve(strict=True)
        if not release.is_relative_to(base / "releases"):
            raise RuntimeError("Активная версия вне releases")
        manifest = json.loads((release / "manifest.json").read_text())
        env = os.environ.copy()
        env["NAYORI_NOTIFICATIONS"] = (
            "1" if "notifications" in manifest["components"] else "0"
        )
        process = subprocess.Popen(
            ["qs", "-p", str(release), "--no-duplicate"], env=env, pass_fds=(fd,)
        )
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
