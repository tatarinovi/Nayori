"""List folders and wallpaper files at one level of a collection."""
import json
import os
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit


EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp'}


def images(folder):
    url = urlsplit(folder)
    if url.scheme != 'file' or url.netloc not in ('', 'localhost'):
        return []
    base = Path(unquote(url.path))
    if not base.is_absolute():
        return []
    result = []
    try:
        with os.scandir(base) as entries:
            for entry in entries:
                if entry.name.startswith('.'):
                    continue
                try:
                    # Never enter directory symlinks (including cycles).
                    is_folder = entry.is_dir(follow_symlinks=False)
                    if not is_folder and (Path(entry.name).suffix.lower() not in EXTENSIONS or not entry.is_file()):
                        continue
                    result.append({'fileName': entry.name, 'fileUrl': Path(entry.path).as_uri(), 'isFolder': is_folder})
                except OSError:
                    continue
    except OSError:
        return []
    return sorted(result, key=lambda item: (not item['isFolder'], item['fileName'].casefold(), item['fileUrl']))


if __name__ == '__main__':
    print(json.dumps(images(sys.argv[1]), ensure_ascii=True))
