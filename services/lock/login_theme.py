"""Publish data-only SDDM appearance snapshots, with atomic config replacement.

No authentication data or executable files are exported. System installation is
separate. The installed theme.conf.user symlink points to the shared snapshot.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import unquote, urlsplit

COLOR_KEYS = ('background', 'surface', 'surfaceAlt', 'text', 'textMuted',
              'accent', 'accentText', 'border')
MODES = ('fill', 'fit', 'stretch', 'center')
SHARED = Path('/var/lib/nayori-sddm')


def atomic_write(path, data):
    fd, temporary = tempfile.mkstemp(prefix='.nayori-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def ini_string(value):
    # QSettings INI quoting; commas and JSON quotes must survive QString parsing.
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


def validate(payload):
    colors = payload['colors']
    if any(not re.fullmatch(r'#[\da-fA-F]{6}(?:[\da-fA-F]{2})?', colors.get(k, '')) for k in COLOR_KEYS):
        raise ValueError('Invalid palette')
    if not isinstance(payload['primaryOutput'], str) or len(payload['primaryOutput']) > 256:
        raise ValueError('Invalid output')
    if not isinstance(payload['wallpapers'], dict) or len(payload['wallpapers']) > 32:
        raise ValueError('Invalid wallpapers')
    for value in [payload['wallpaper'], *payload['wallpapers'].values()]:
        if value.get('mode') not in MODES or not isinstance(value.get('source'), str):
            raise ValueError('Invalid wallpaper')
    return payload


def copy_wallpaper(value, directory):
    parsed = urlsplit(value['source'])
    if parsed.scheme != 'file' or parsed.netloc not in ('', 'localhost'):
        raise ValueError('Wallpaper must be a local file')
    source = Path(unquote(parsed.path))
    if source.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp'):
        raise ValueError('Unsupported wallpaper format')
    with source.open('rb') as stream:
        data = stream.read(64 * 1024 * 1024 + 1)
    if len(data) > 64 * 1024 * 1024:
        raise ValueError('Wallpaper exceeds 64 MiB')
    target = directory / (hashlib.sha256(data).hexdigest() + source.suffix.lower())
    if not target.exists():
        atomic_write(target, data)
    return dict(source=target.as_uri(), mode=value['mode'])


def publish(payload, directory):
    validate(payload)
    directory = directory.resolve()
    directory.mkdir(parents=True, exist_ok=True, mode=0o755)
    wallpaper = copy_wallpaper(payload['wallpaper'], directory)
    wallpapers = {name: copy_wallpaper(value, directory) for name, value in payload['wallpapers'].items()}
    values = {key: payload['colors'][key] for key in COLOR_KEYS}
    values.update(primaryOutput=payload['primaryOutput'], wallpaper=wallpaper['source'], wallpaperMode=wallpaper['mode'],
                  animationsEnabled='true' if payload.get('animationsEnabled', True) else 'false',
                  enterDuration=str(max(0, min(300, int(payload.get('enterDuration', 220))))),
                  exitDuration=str(max(0, min(300, int(payload.get('exitDuration', 140))))),
                  wallpapers=json.dumps(wallpapers, ensure_ascii=False, separators=(',', ':')))
    text = '[General]\n' + ''.join(f'{key}={ini_string(value)}\n' for key, value in values.items())
    atomic_write(directory / 'theme.conf.user', text.encode())


def sync_snapshot(source, destination):
    text = (source / 'theme.conf.user').read_text()
    destination.mkdir(parents=True, exist_ok=True, mode=0o755)
    for image in source.iterdir():
        if re.fullmatch(r'[a-f0-9]{64}\.(png|jpe?g|webp|avif|bmp)', image.name) and image.as_uri() in text:
            atomic_write(destination / image.name, image.read_bytes())
    atomic_write(destination / 'theme.conf.user', text.replace(source.as_uri(), destination.as_uri()).encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--json')
    mode.add_argument('--sync', action='store_true', help='Publish the latest local snapshot after installation')
    parser.add_argument('--directory', type=Path)
    args = parser.parse_args()
    data_home = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    local = (data_home / 'nayori/sddm').resolve()
    if args.sync:
        target = args.directory.resolve() if args.directory else SHARED
        if not args.directory and (not target.is_dir() or target.stat().st_uid != os.getuid()):
            raise ValueError('Install the theme for this account before publishing to /var/lib/nayori-sddm')
        sync_snapshot(local, target)
        return
    payload = validate(json.loads(args.json))
    if args.directory:
        publish(payload, args.directory)
    else:
        publish(payload, local)
        # Never prompt for privilege or create /var/lib directories at runtime.
        if SHARED.is_dir() and SHARED.stat().st_uid == os.getuid():
            publish(payload, SHARED)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit(str(error))
