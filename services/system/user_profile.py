"""Read the current account without changing system or session settings."""
import json
import os
import pwd
import shlex
import socket
import subprocess
from pathlib import Path


def profile():
    account = pwd.getpwuid(os.getuid())
    candidates = []
    try:
        result = subprocess.run(
            ['busctl', '--system', 'get-property', 'org.freedesktop.Accounts',
             f'/org/freedesktop/Accounts/User{account.pw_uid}',
             'org.freedesktop.Accounts.User', 'IconFile'],
            capture_output=True, text=True, timeout=2, check=True)
        values = shlex.split(result.stdout)
        if len(values) == 2 and values[0] == 's' and values[1]:
            candidates.append(Path(values[1]))
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    home = Path(account.pw_dir)
    candidates.extend([home / '.face', home / '.face.icon',
                       Path('/var/lib/AccountsService/icons') / account.pw_name])
    avatar = next((p.resolve().as_uri() for p in candidates
                   if p.is_file() and os.access(p, os.R_OK)), '')
    try:
        uptime = int(float(Path('/proc/uptime').read_text().split()[0]))
    except (OSError, ValueError, IndexError):
        uptime = -1
    return dict(username=account.pw_name, hostname=socket.gethostname(),
                avatar=avatar, uptime=uptime)


if __name__ == '__main__':
    print(json.dumps(profile()))
