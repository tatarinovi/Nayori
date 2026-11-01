#!/usr/bin/env python3
"""Exercise the package update service only with harmless stand-ins."""
import os
import pathlib
import subprocess
import tempfile

repo = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="nayori-update-test-") as temp:
    root = pathlib.Path(temp)
    binaries = root / "bin"
    binaries.mkdir()
    for name, body in {
        "yay": 'printf "%s\\n" "$@" > "$HOME/yay-args"\nsudo -A -v || exit 1\nsudo -A -v || exit 1\necho "there is nothing to do"\nexit 0\n',
        "pacman": 'echo "fake failure" >&2\nexit 1\n',
        "sudo": 'printf "%s\\n" "$@" > "$HOME/sudo-args"\nif [ ! -f "$HOME/authorized" ]; then "$SUDO_ASKPASS" >/dev/null || exit 1; touch "$HOME/authorized"; fi\nshift\n[ "$1" = -v ] && exit 0\nexec "$@"\n',
        "zenity": 'echo dialog >> "$HOME/dialog-count"\nprintf "test-password\\n"\n',
    }.items():
        path = binaries / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)
    runtime = root / "run"
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    env.update({"PATH": str(binaries) + ":/usr/bin:/bin", "HOME": temp,
                "XDG_RUNTIME_DIR": str(runtime), "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_CACHE_HOME": str(root / "cache"), "XDG_STATE_HOME": str(root / "state"),
                "XDG_DATA_HOME": str(root / "data"), "QT_QPA_PLATFORM": "offscreen",
                "QT_QPA_PLATFORMTHEME": "basic", "QT_QUICK_BACKEND": "software",
                "QS_DISABLE_FILE_WATCHER": "1"})
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "NIRI_SOCKET"):
        env.pop(key, None)
    result = subprocess.run(["/usr/bin/qs", "-p", str(repo / "tests/smoke/SystemUpdateSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=20, check=False)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or "SYSTEM_UPDATE_SMOKE_PASS" not in output or "SYSTEM_UPDATE_FAIL" in output:
        raise SystemExit(1)
    yay_args = (root / "yay-args").read_text().splitlines()
    assert yay_args[:2] == ["-Syu", "--noconfirm"]
    assert yay_args[yay_args.index("--sudo") + 1] == "sudo"
    assert "--sudoloop" in yay_args
    assert (root / "dialog-count").read_text().splitlines() == ["dialog"]
    assert (root / "sudo-args").read_text().splitlines()[:3] == ["-A", "pacman", "-Syu"]
    second_dir = root / "askpass-guard"
    second_dir.mkdir()
    env["NAYORI_UPDATE_AUTH_DIR"] = str(second_dir)
    helper = str(repo / "scripts/system-update-askpass")
    assert subprocess.run([helper], env=env, stdout=subprocess.DEVNULL, check=False).returncode == 0
    assert subprocess.run([helper], env=env, stdout=subprocess.DEVNULL, check=False).returncode != 0
    result = subprocess.run(["/usr/bin/qs", "-p", str(repo / "tests/smoke/SystemUpdateUiSmoke.qml"), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=20, check=False)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and "SYSTEM_UPDATE_UI_PASS" in output and "SYSTEM_UPDATE_UI_FAIL" not in output
    (root / "authorized").unlink()
    (binaries / "zenity").write_text("#!/bin/sh\nexit 1\n")
    result = subprocess.run([str(repo / "scripts/system-update"), "yay"],
                            env=env, capture_output=True, text=True, timeout=10, check=False)
    assert result.returncode != 0
