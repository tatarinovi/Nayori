#!/usr/bin/env python3
"""Install the Nayori theme without starting/stopping a display manager.

Run as root after reviewing the theme in SDDM test mode. --root is available for
staging/tests. A separate, explicit --select-theme writes SDDM's theme setting.
"""
import argparse
from datetime import datetime
import os
from pathlib import Path
import pwd
import shutil
import sys

REPO = Path(__file__).resolve().parents[1]


def backup(path):
    if path.exists() or path.is_symlink():
        suffix = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        path.rename(path.with_name(path.name + '.bak-' + suffix))


def install(root, owner, select_theme=False):
    if root == Path('/') and os.geteuid() != 0:
        raise PermissionError('Run this installer with sudo')
    theme = root / 'usr/share/sddm/themes/nayori'
    data = root / 'var/lib/nayori-sddm'
    theme.parent.mkdir(parents=True, exist_ok=True)
    backup(theme)
    shutil.copytree(REPO / 'sddm/nayori', theme, ignore=shutil.ignore_patterns('theme.conf.user'))
    shutil.copyfile(REPO / 'assets/wallpapers/nayori.png', theme / 'wallpaper.png')
    # A readable bundled wallpaper remains available before the first export.
    config = theme / 'theme.conf'
    config.write_text(config.read_text().replace('wallpaper=\n', 'wallpaper=wallpaper.png\n'))
    data.mkdir(parents=True, exist_ok=True, mode=0o755)
    os.chmod(data, 0o755)
    # Only this data directory is writable by the desktop user. QML stays root-owned.
    os.chown(data, owner.pw_uid, owner.pw_gid)
    (theme / 'theme.conf.user').symlink_to('/var/lib/nayori-sddm/theme.conf.user')
    if select_theme:
        selection = root / 'etc/sddm.conf.d/90-nayori.conf'
        selection.parent.mkdir(parents=True, exist_ok=True)
        backup(selection)
        selection.write_text('[Theme]\nCurrent=nayori\n')
    print(f'Theme installed: {theme}')
    print(f'Appearance data: {data} (owner: {owner.pw_name})')
    print('No services were started, stopped, enabled or disabled.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', required=True, help='Desktop account that publishes its palette')
    parser.add_argument('--root', type=Path, default=Path('/'))
    parser.add_argument('--select-theme', action='store_true')
    args = parser.parse_args()
    install(args.root.resolve(), pwd.getpwnam(args.owner), args.select_theme)


if __name__ == '__main__':
    try:
        main()
    except (OSError, KeyError) as error:
        sys.exit(str(error))
