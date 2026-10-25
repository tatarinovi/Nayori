"""Preserve exact bytes before explicitly recovering a corrupt settings file."""
import os
from pathlib import Path
import sys
import tempfile

source = Path(sys.argv[1])
try:
    data = source.read_bytes()
    fd, name = tempfile.mkstemp(prefix=source.name + ".backup-", dir=source.parent)
    try:
        with os.fdopen(fd, "wb") as backup:
            backup.write(data)
            backup.flush()
            os.fsync(backup.fileno())
    except BaseException:
        Path(name).unlink(missing_ok=True)
        raise
    directory_fd = os.open(source.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)
    print(name)
except OSError as error:
    print(error, file=sys.stderr)
    sys.exit(1)
