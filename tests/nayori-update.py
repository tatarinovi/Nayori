import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from unittest import mock

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('nayori_update', root / 'scripts/nayori-update.py')
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)

with tempfile.TemporaryDirectory(prefix='nayori-update-test-') as tmp:
    home = Path(tmp)
    env = {'HOME': str(home), 'XDG_DATA_HOME': str(home / 'data'),
           'XDG_STATE_HOME': str(home / 'state'), 'XDG_CONFIG_HOME': str(home / 'config')}
    with mock.patch.dict(os.environ, env):
        paths = update.Paths()
        old = paths.base / 'releases' / 'old'
        old.mkdir(parents=True)
        (old / 'manifest.json').write_text(json.dumps({'commit': 'a' * 40, 'components': ['nayori']}))
        (old / 'scripts/installer').mkdir(parents=True)
        (old / 'scripts/installer/launcher.py').write_text((root / 'scripts/installer/launcher.py').read_text())
        (paths.base / 'current').symlink_to('releases/old')
        update.SCRIPT_ROOT = root
        assert update.execute('check') == {'ok': True, 'installed': False}
        update.SCRIPT_ROOT = old
        new = paths.base / 'releases' / 'new'
        new.mkdir()
        (new / 'manifest.json').write_text(json.dumps({'commit': 'b' * 40, 'components': ['nayori']}))
        (new / 'scripts/installer').mkdir(parents=True)
        (new / 'scripts/installer/launcher.py').write_text((root / 'scripts/installer/launcher.py').read_text())
        paths.bin.mkdir(parents=True)
        (paths.bin / 'nayori').write_text('old launcher')
        def fake_git(*args):
            if args[0] == 'ls-remote': return 'b' * 40 + '\trefs/heads/main'
            if args[0] == 'clone': return ''
            if args[-1] == 'HEAD': return 'b' * 40
            raise AssertionError(args)
        with mock.patch.object(update, 'git', side_effect=fake_git), mock.patch.object(update.Engine, '_copy_release', return_value=new):
            checked = update.execute('check')
            assert checked['available'] and checked['latest'] == 'b' * 40
            try:
                update.execute('apply', 'c' * 40)
                raise AssertionError('changed main accepted')
            except update.InstallError:
                assert (paths.base / 'current').resolve() == old
            applied = update.execute('apply', checked['latest'])
            assert applied['rollback'] and (paths.base / 'current').resolve() == new
            assert 'INSTALL_BASE = ' + repr(str(paths.base)) in (paths.bin / 'nayori').read_text()
            assert (paths.base / 'previous').resolve() == old
            rolled = update.execute('rollback')
            assert rolled['current'] == 'a' * 40 and (paths.base / 'current').resolve() == old
            assert (paths.base / 'previous').resolve() == new
        invalid = home / 'invalid'
        (invalid / 'scripts/installer').mkdir(parents=True)
        (invalid / 'scripts/installer/launcher.py').write_text('invalid launcher')
        before = (paths.bin / 'nayori').read_text()
        try:
            update.update_launcher(paths, invalid)
            raise AssertionError('invalid launcher accepted')
        except update.InstallError:
            assert (paths.bin / 'nayori').read_text() == before
        runtime = home / 'runtime' / 'nayori'
        runtime.mkdir(parents=True)
        launcher = paths.bin / 'nayori'
        launcher.write_text('#!/bin/sh\n')
        launcher.chmod(0o700)
        record = {'pid': 1234, 'start': '999', 'release': str(old)}
        (runtime / 'active.json').write_text(json.dumps(record))
        (runtime / 'instance.lock').touch()
        with mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime.parent)}), \
             mock.patch.object(update, 'process_start', return_value='999'), \
             mock.patch.object(update.subprocess, 'Popen') as spawn:
            assert update.prepare_restart(paths, 1234)['ok']
            assert spawn.call_args.args[0][2:4] == ['_restart', '1234']
            try:
                update.prepare_restart(paths, 4321)
                raise AssertionError('foreign process accepted')
            except update.InstallError:
                pass
            spawn.reset_mock()
            with mock.patch.object(update.os, 'kill') as kill:
                update.restart_process(1234, '999', launcher, runtime)
                kill.assert_called_once_with(1234, update.signal.SIGTERM)
                assert spawn.call_args.args[0] == [str(launcher)]
                kill.reset_mock()
                try:
                    update.restart_process(1234, 'outdated', launcher, runtime)
                    raise AssertionError('stale process accepted')
                except update.InstallError:
                    kill.assert_not_called()
        launcher.unlink()
        with mock.patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime.parent)}), \
             mock.patch.object(update, 'process_start', return_value='999'), \
             mock.patch.object(update.subprocess, 'Popen') as spawn:
            try:
                update.prepare_restart(paths, 1234)
                raise AssertionError('missing launcher accepted')
            except update.InstallError:
                spawn.assert_not_called()
print('Nayori update tests passed')

with tempfile.TemporaryDirectory(prefix='nayori-launcher-lock-test-') as tmp:
    home = Path(tmp)
    base, runtime, binaries = home / 'data/nayori', home / 'run', home / 'bin'
    runtime.mkdir(mode=0o700)
    binaries.mkdir()
    release = base / 'releases/one'
    release.mkdir(parents=True)
    (release / 'manifest.json').write_text('{"components": []}')
    (base / 'current').symlink_to('releases/one')
    launcher = binaries / 'nayori'
    launcher.write_text((root / 'scripts/installer/launcher.py').read_text().replace(
        'INSTALL_BASE = None', 'INSTALL_BASE = ' + repr(str(base))))
    launcher.chmod(0o755)
    fake = binaries / 'qs'
    fake.write_text('#!/usr/bin/env python3\nimport os,subprocess,time\n'
                    'child = subprocess.Popen(["sleep", "30"], close_fds=False)\n'
                    'open(os.environ["CHILD_PID"], "w").write(str(child.pid))\n'
                    'time.sleep(30)\n')
    fake.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), PATH=str(binaries) + ':' + os.environ['PATH'],
               CHILD_PID=str(home / 'child'))
    process = subprocess.Popen([str(launcher)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    child = None
    try:
        for _ in range(250):
            if (home / 'child').exists() and (runtime / 'nayori/active.json').exists():
                break
            time.sleep(.02)
        child = int((home / 'child').read_text())
        assert subprocess.run([str(launcher)], env=env, capture_output=True).returncode != 0
        process.terminate()
        process.wait(timeout=5)
        lock = os.open(runtime / 'nayori/instance.lock', os.O_RDWR)
        try:
            update.fcntl.flock(lock, update.fcntl.LOCK_EX | update.fcntl.LOCK_NB)
        finally:
            os.close(lock)
        # A live orphaned shell recorded after launcher death still blocks a duplicate.
        start = update.process_start(child)
        (runtime / 'nayori/active.json').write_text(json.dumps({'pid': child, 'start': start}))
        result = subprocess.run([str(launcher)], env=env, capture_output=True, timeout=5)
        assert result.returncode != 0 and 'уже запущена' in result.stderr.decode()
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        if child is not None:
            try:
                os.kill(child, update.signal.SIGTERM)
            except ProcessLookupError:
                pass
print('Nayori launcher lock tests passed')
