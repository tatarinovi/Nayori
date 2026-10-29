#!/usr/bin/env python3
"""Check and switch installed Nayori releases; never modify a source checkout."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

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


def execute(operation, wanted=None):
    paths = Paths()
    if not installed(paths):
        return {'ok': True, 'installed': False}
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
