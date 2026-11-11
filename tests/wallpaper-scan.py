"""Folder navigation, URL encoding and unavailable paths."""
import importlib.util
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wallpaper_library', root / 'services/canvas/wallpaper_library.py')
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    nested = base / 'nested папка' / 'deeper #1'
    nested.mkdir(parents=True)
    for path in (base / 'same.png', nested / 'same.png', nested / 'Фото %.JPEG'):
        path.touch()
    (base / 'alias.WebP').symlink_to(nested / 'same.png')
    (nested / 'cycle').symlink_to(base, target_is_directory=True)
    (base / 'broken.png').symlink_to(base / 'missing')
    (nested / 'notes.txt').touch()
    (nested / '.hidden.png').touch()
    hidden = base / '.hidden'
    hidden.mkdir()
    (hidden / 'ignored.png').touch()
    denied = base / 'unreadable'
    denied.mkdir()
    (denied / 'secret.png').touch()
    denied.chmod(0)
    try:
        rows = scanner.images(base.as_uri())
        assert len(rows) == 4, rows
        assert [row['isFolder'] for row in rows] == [True, True, False, False]
        assert sum(row['fileName'] == 'same.png' for row in rows) == 1
        children = scanner.images((base / 'nested папка').as_uri())
        assert children == [{'fileName': nested.name, 'fileUrl': nested.as_uri(), 'isFolder': True}]
        rows = scanner.images(nested.as_uri())
        assert len(rows) == 2, rows
        assert {'fileName': 'Фото %.JPEG', 'fileUrl': (nested / 'Фото %.JPEG').as_uri(), 'isFolder': False} in rows
        assert scanner.images(denied.as_uri()) == []
        (nested / 'new.png').touch()
        assert len(scanner.images(nested.as_uri())) == 3
        (nested / 'same.png').unlink()
        assert len(scanner.images(nested.as_uri())) == 2
        assert len(scanner.images(base.as_uri())) == 3  # Broken alias disappears.
        assert scanner.images((base / 'missing').as_uri()) == []
        assert scanner.images('https://example.org/images') == []
    finally:
        denied.chmod(0o700)
print('PASS wallpaper folders, navigation, escaped URLs, hidden/unreadable paths and symlink cycles')
