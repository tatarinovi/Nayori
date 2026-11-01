#!/usr/bin/env python3
"""Check and switch installed Nayori releases; never modify a source checkout."""
import json
import fcntl
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from installer.core import Engine, Paths, InstallError, sync_directory

REMOTE = 'https://github.com/tatarinovi/Nayori.git'
SCRIPT_ROOT = Path(__file__).resolve().parents[1]
SHA = re.compile(r'^[0-9a-f]{40}$')


def git(*args):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_CONFIG_NOSYSTEM='1')
    result = subprocess.run(['git', *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=120, env=env)
    if result.returncode:
        raise InstallError(result.stderr.strip() or 'Ошибка Git')
    return result.stdout.strip()


def release(paths, name):
    link = paths.base / name
    if not link.is_symlink():
        raise InstallError('Установленная версия не найдена')
    target = link.resolve(strict=True)
    if target.parent != (paths.base / 'releases').resolve() or not (target / 'manifest.json').is_file():
        raise InstallError('Некорректный указатель версии')
    return target


def installed(paths):
    releases = (paths.base / 'releases').resolve()
    return SCRIPT_ROOT.parent == releases and (SCRIPT_ROOT / 'manifest.json').is_file()


def switch(paths, name, target):
    link = paths.base / ('.update-' + name + '-' + os.urandom(8).hex())
    try:
        link.symlink_to(target.relative_to(paths.base))
        os.replace(link, paths.base / name)
        sync_directory(paths.base)
    finally:
        link.unlink(missing_ok=True)


def state(paths):
    current = release(paths, 'current')
    manifest = json.loads((current / 'manifest.json').read_text())
    try:
        previous = release(paths, 'previous') != current
    except (InstallError, OSError):
        previous = False
    return current, manifest, previous


def update_launcher(paths, target):
    source = (target / 'scripts/installer/launcher.py').read_text()
    marker = 'INSTALL_BASE = None'
    if source.count(marker) != 1:
        raise InstallError('Некорректный launcher в обновлении')
    launcher = paths.bin / 'nayori'
    if launcher.is_symlink() or not launcher.is_file():
        raise InstallError('Установленный launcher недоступен')
    fd, name = tempfile.mkstemp(prefix='.nayori-launcher-', dir=paths.bin)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(source.replace(marker, 'INSTALL_BASE = ' + repr(str(paths.base))))
            stream.flush()
            os.fchmod(stream.fileno(), 0o755)
            os.fsync(stream.fileno())
        os.replace(name, launcher)
        sync_directory(paths.bin)
    finally:
        Path(name).unlink(missing_ok=True)


def process_start(pid):
    return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]


def prepare_restart(paths, parent_pid):
    if not installed(paths):
        raise InstallError('Перезапуск доступен только установленной Nayori')
    runtime = Path(os.environ['XDG_RUNTIME_DIR']) / 'nayori'
    record = json.loads((runtime / 'active.json').read_text())
    if (record['pid'] != parent_pid or record['start'] != process_start(parent_pid)
            or Path(record['release']).resolve() != SCRIPT_ROOT):
        raise InstallError('Не удалось определить работающую оболочку')
    launcher = paths.bin / 'nayori'
    if not launcher.is_file() or not os.access(launcher, os.X_OK):
        raise InstallError('Launcher Nayori недоступен')
    # Also migrate installations whose previous updater did not refresh the launcher.
    update_launcher(paths, SCRIPT_ROOT)
    subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '_restart',
                      str(parent_pid), record['start'], str(launcher), str(runtime)],
                     start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)
    return {'ok': True, 'installed': True, 'message': 'Перезапускаем Nayori'}


def restart_process(pid, start, launcher, runtime):
    # Only the launcher-registered process can be stopped; recheck against PID reuse.
    record = json.loads((runtime / 'active.json').read_text())
    if record['pid'] != pid or record['start'] != start or process_start(pid) != start:
        raise InstallError('Запись работающей оболочки устарела')
    fd = os.open(runtime / 'instance.lock', os.O_RDWR | os.O_NOFOLLOW)
    try:
        os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 15
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise InstallError('Оболочка не завершилась')
                time.sleep(0.1)
    finally:
        os.close(fd)
    subprocess.Popen([str(launcher)], start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)


def execute(operation, wanted=None):
    paths = Paths()
    if not installed(paths):
        return {'ok': True, 'installed': False}
    if operation == 'restart':
        return prepare_restart(paths, os.getppid())
    engine = Engine(paths=paths)
    lock = engine.lock()
    try:
        if engine.pending():
            raise InstallError('Сначала завершите восстановление прерванной установки')
        current, manifest, previous = state(paths)
        if operation == 'check':
            remote = git('ls-remote', '--exit-code', REMOTE, 'refs/heads/main').split()[0]
            if not SHA.fullmatch(remote):
                raise InstallError('Git вернул некорректный идентификатор коммита')
            commit = manifest.get('commit', 'unknown')
            return {'ok': True, 'installed': True, 'current': commit, 'latest': remote,
                    'available': commit != remote, 'rollback': previous}
        if operation == 'apply':
            if not wanted or not SHA.fullmatch(wanted):
                raise InstallError('Сначала проверьте обновления')
            with tempfile.TemporaryDirectory(prefix='nayori-update-') as tmp:
                source = Path(tmp) / 'source'
                git('clone', '--quiet', '--single-branch', '--branch', 'main', REMOTE, str(source))
                commit = git('-C', str(source), 'rev-parse', 'HEAD')
                if commit != wanted:
                    raise InstallError('Ветка main изменилась. Проверьте обновления ещё раз')
                if commit == manifest.get('commit'):
                    raise InstallError('Эта версия уже установлена')
                new = Engine(paths=paths, source=source)._copy_release(manifest.get('components', ['nayori']))
                if release(paths, 'current') != current:
                    raise InstallError('Установленная версия изменилась во время обновления')
                update_launcher(paths, new)
                switch(paths, 'previous', current)
                switch(paths, 'current', new)
            return {'ok': True, 'installed': True, 'current': commit, 'latest': commit,
                    'available': False, 'rollback': True, 'message': 'Обновление установлено. Перезапустите Nayori.'}
        if operation == 'rollback':
            if not previous:
                raise InstallError('Предыдущая версия недоступна')
            target = release(paths, 'previous')
            switch(paths, 'current', target)
            switch(paths, 'previous', current)
            commit = json.loads((target / 'manifest.json').read_text()).get('commit', 'unknown')
            return {'ok': True, 'installed': True, 'current': commit, 'latest': '',
                    'available': False, 'rollback': True, 'message': 'Версия восстановлена. Перезапустите Nayori.'}
        raise InstallError('Неизвестная операция')
    finally:
        os.close(lock)


if __name__ == '__main__':
    try:
        if sys.argv[1] == '_restart':
            restart_process(int(sys.argv[2]), sys.argv[3], Path(sys.argv[4]), Path(sys.argv[5]))
            sys.exit(0)
        result = execute(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    except Exception as error:
        paths = Paths()
        result = {'ok': False, 'installed': installed(paths), 'error': str(error) or 'Не удалось выполнить обновление'}
        if result['installed']:
            try:
                _, manifest, previous = state(paths)
                result.update(current=manifest.get('commit', 'unknown'), rollback=previous)
            except (OSError, ValueError, InstallError):
                pass
    print(json.dumps(result, ensure_ascii=False))
