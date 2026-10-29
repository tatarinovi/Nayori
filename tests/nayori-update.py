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
print('Nayori update tests passed')
