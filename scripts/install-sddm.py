#!/usr/bin/env python3
"""Install the Nayori theme without starting/stopping a display manager.

Run as root after reviewing the theme in SDDM test mode. --root is available for
staging/tests. A separate, explicit --select-theme writes SDDM's theme setting.
"""

import argparse
import fcntl
from datetime import datetime
import os
from pathlib import Path
import pwd
import shutil
import sys
import re
import tempfile
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent))
from installer.core import Transaction, InstallError, exists, safe_directory

REPO = Path(__file__).resolve().parents[1]


def backup(path):
    if path.exists() or path.is_symlink():
        suffix = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        path.rename(path.with_name(path.name + ".bak-" + suffix))


def install(root, owner, select_theme=False):
    if root == Path("/") and os.geteuid() != 0:
        raise PermissionError("Run this installer with sudo")
    theme = root / "usr/share/sddm/themes/nayori"
    data = root / "var/lib/nayori-sddm"
    theme.parent.mkdir(parents=True, exist_ok=True)
    backup(theme)
    shutil.copytree(
        REPO / "sddm/nayori",
        theme,
        symlinks=True,
        ignore=shutil.ignore_patterns("theme.conf.user"),
    )
    if any(path.is_symlink() for path in theme.rglob("*")):
        raise PermissionError("Symlinks in theme sources are not allowed")
    shutil.copyfile(
        REPO / "assets/wallpapers/nayori.png",
        theme / "wallpaper.png",
        follow_symlinks=False,
    )
    if (theme / "wallpaper.png").is_symlink():
        raise PermissionError("Wallpaper must be a regular file")
    # A readable bundled wallpaper remains available before the first export.
    config = theme / "theme.conf"
    config.write_text(
        config.read_text().replace("wallpaper=\n", "wallpaper=wallpaper.png\n")
    )
    data.mkdir(parents=True, exist_ok=True, mode=0o755)
    os.chmod(data, 0o755)
    # Only this data directory is writable by the desktop user. QML stays root-owned.
    os.chown(data, owner.pw_uid, owner.pw_gid)
    (theme / "theme.conf.user").symlink_to("/var/lib/nayori-sddm/theme.conf.user")
    if select_theme:
        selection = root / "etc/sddm.conf.d/90-nayori.conf"
        selection.parent.mkdir(parents=True, exist_ok=True)
        backup(selection)
        selection.write_text("[Theme]\nCurrent=nayori\n")
    print(f"Theme installed: {theme}")
    print(f"Appearance data: {data} (owner: {owner.pw_name})")
    print("No services were started, stopped, enabled or disabled.")


def _transactional(
    root, owner=None, select_theme=False, transaction_id=None, rollback=False
):
    """Root-owned journal; GUI never edits privileged rollback metadata."""
    if root == Path("/") and os.geteuid() != 0:
        raise PermissionError("Run this operation with sudo")
    if not re.fullmatch(r"[0-9a-f]{32}", transaction_id or ""):
        raise ValueError("Invalid transaction id")
    state = root / "var/lib/nayori-installer"
    for parent in reversed(state.parents):
        if parent not in (Path("/"), Path("/tmp")) and parent.exists():
            safe_directory(parent)
    safe_directory(state)
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    state = state / transaction_id
    safe_directory(state)
    paths = SimpleNamespace(state=state)
    theme = root / "usr/share/sddm/themes/nayori"
    data = root / "var/lib/nayori-sddm"
    selection = root / "etc/sddm.conf.d/90-nayori.conf"
    if rollback:
        file = state / "transaction.json"
        if not file.exists():
            print("SDDM transaction did not start; nothing to restore.")
            return
        import json

        record = json.loads(file.read_text())
        if record["status"] == "restored":
            return
        for op in record["operations"]:
            dest = Path(op["destination"])
            if (
                dest not in (theme, data, selection)
                or Path(op["backup"]).parent != dest.parent
            ):
                raise ValueError("Invalid privileged rollback target")
        Transaction(paths, record=record).restore(allow_modified=True)
        print("SDDM files restored; services unchanged.")
        return
    if (state / "transaction.json").exists():
        raise ValueError("Transaction already exists")
    for target in (theme, data, selection):
        for parent in reversed(target.parents):
            if parent not in (Path("/"), Path("/tmp")) and parent.exists():
                safe_directory(parent)
    tx = Transaction(paths)
    tx.record["id"] = transaction_id
    tx.save()
    theme.parent.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(
            prefix=".nayori-sddm-", dir=theme.parent
        ) as temp:
            staged_root = Path(temp)
            # Existing rendering/layout stays identical to the standalone installer.
            install(staged_root, owner, select_theme)
            tx.replace(theme, staged_root / "usr/share/sddm/themes/nayori")
            if exists(data):
                info = data.lstat()
                if (
                    data.is_symlink()
                    or not data.is_dir()
                    or info.st_uid != owner.pw_uid
                    or info.st_mode & 0o022
                ):
                    raise PermissionError("Unsafe appearance data directory")
            else:
                data.parent.mkdir(parents=True, exist_ok=True)
                data_stage = Path(
                    tempfile.mkdtemp(prefix=".nayori-data-", dir=data.parent)
                )
                os.chmod(data_stage, 0o755)
                os.chown(data_stage, owner.pw_uid, owner.pw_gid)
                tx.replace(data, data_stage)
            if select_theme:
                selection.parent.mkdir(parents=True, exist_ok=True)
                # Staged root can be on another filesystem: copy to a sibling first.
                fd, name = tempfile.mkstemp(
                    prefix=".nayori-sddm-", dir=selection.parent
                )
                with os.fdopen(fd, "w") as stream:
                    stream.write("[Theme]\nCurrent=nayori\n")
                Path(name).chmod(0o644)
                tx.replace(selection, Path(name))
            tx.commit()
    except Exception:
        tx.restore(allow_modified=True)
        raise


def transactional(
    root, owner=None, select_theme=False, transaction_id=None, rollback=False
):
    if root == Path("/") and os.geteuid() != 0:
        raise PermissionError("Run this operation with sudo")
    state = root / "var/lib/nayori-installer"
    for path in reversed([state, *state.parents]):
        if path not in (Path("/"), Path("/tmp")):
            safe_directory(path)
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(state / ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _transactional(root, owner, select_theme, transaction_id, rollback)
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", help="Desktop account name or UID")
    parser.add_argument("--root", type=Path, default=Path("/"))
    parser.add_argument("--select-theme", action="store_true")
    parser.add_argument("--transaction", help="Installer transaction id")
    parser.add_argument("--rollback", help="Restore a privileged transaction")
    args = parser.parse_args()
    if args.rollback:
        transactional(args.root.resolve(), transaction_id=args.rollback, rollback=True)
        return
    if not args.owner:
        parser.error("--owner is required for installation")
    owner = (
        pwd.getpwuid(int(args.owner))
        if args.owner.isdigit()
        else pwd.getpwnam(args.owner)
    )
    if args.transaction:
        transactional(args.root.resolve(), owner, args.select_theme, args.transaction)
    else:
        install(args.root.resolve(), owner, args.select_theme)


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, ValueError, InstallError) as error:
        sys.exit(str(error))
