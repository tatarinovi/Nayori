#!/usr/bin/env python3
"""Exercise real yay with an empty disposable database and fake privileged tools."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
real_yay = shutil.which("yay")
if not real_yay:
    print("SKIP yay is not installed")
    raise SystemExit(0)

with tempfile.TemporaryDirectory(prefix="nayori-yay-isolated-") as temp:
    root = Path(temp)
    binary = root / "bin"
    binary.mkdir()
    (root / "db/local").mkdir(parents=True)
    (root / "db/sync").mkdir()
    (root / "cache").mkdir()
    (root / "config").mkdir()
    pacman_config = root / "pacman.conf"
    pacman_config.write_text("[options]\nArchitecture = auto\n", encoding="utf-8")
    for name in ("sudo", "pacman"):
        path = binary / name
        path.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$HOME/calls"\nexit 0\n', encoding="utf-8")
        path.chmod(0o755)
    yay = binary / "yay"
    yay.write_text("#!/bin/sh\nexec " + shlex.quote(real_yay) + ' "$@" --config '
                   + shlex.quote(str(pacman_config)) + " --dbpath " + shlex.quote(str(root / "db"))
                   + " --pacman " + shlex.quote(str(binary / "pacman")) + "\n", encoding="utf-8")
    yay.chmod(0o755)
    env = {"PATH": str(binary) + ":/usr/bin:/bin", "HOME": temp,
           "XDG_CONFIG_HOME": str(root / "config"), "XDG_CACHE_HOME": str(root / "cache"),
           "TMPDIR": temp, "LC_ALL": "C"}
    result = subprocess.run([str(repo / "scripts/system-update"), "yay"], env=env,
                            capture_output=True, text=True, timeout=15, check=False)
    calls = (root / "calls").read_text(encoding="utf-8") if (root / "calls").exists() else ""
    assert result.returncode == 0, result.stderr
    assert " -A " in calls and " -v" not in calls, calls
    print("YAY_ISOLATION_PASS")
