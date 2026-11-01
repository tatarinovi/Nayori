import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
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
        (paths.base / 'current').symlink_to('releases/old')
        update.SCRIPT_ROOT = root
        assert update.execute('check') == {'ok': True, 'installed': False}
        update.SCRIPT_ROOT = old
        new = paths.base / 'releases' / 'new'
        new.mkdir()
        (new / 'manifest.json').write_text(json.dumps({'commit': 'b' * 40, 'components': ['nayori']}))
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
            assert (paths.base / 'previous').resolve() == old
            rolled = update.execute('rollback')
            assert rolled['current'] == 'a' * 40 and (paths.base / 'current').resolve() == old
            assert (paths.base / 'previous').resolve() == new
        runtime = home / 'runtime' / 'nayori'
        runtime.mkdir(parents=True)
        (paths.bin).mkdir(parents=True)
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
