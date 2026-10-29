"""Exercise the real helper/QML with a fake nmcli; never touch the host network."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('wireguard_control', ROOT / 'scripts/wireguard-control.py')
control = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(control)
UUID = '11111111-1111-4111-8111-111111111111'


class HelperTests(unittest.TestCase):
    def test_escaping_filter_sort_and_duplicate_names(self):
        rows = (f'Work\\: VPN\\\\lab:{UUID}:wireguard:no::\n'
                'Work:22222222-2222-4222-8222-222222222222:wireguard:yes:activated:wg0\n'
                'Work:33333333-3333-4333-8333-333333333333:wireguard:no::\n'
                'wifi:44444444-4444-4444-8444-444444444444:802-11-wireless:yes:activated:wlan0\n')
        with patch.object(control, 'nmcli', return_value=rows):
            profiles = control.profiles()
        self.assertEqual(len(profiles), 3)
        self.assertEqual(profiles[0]['device'], 'wg0')
        self.assertEqual(profiles[-1]['name'], 'Work: VPN\\lab')

    def test_uuid_and_type_rechecked_before_mutation(self):
        for ident in ('--help', '; echo bad', UUID):
            with patch.object(control, 'nmcli', return_value='') as cli:
                with self.assertRaises(control.ControlError):
                    control.run(['up', ident])
                self.assertFalse(any('up' in call.args for call in cli.call_args_list))

    def test_up_and_down_use_uuid(self):
        for op in ('up', 'down'):
            with patch.object(control, 'profiles', return_value=[{'uuid': UUID}]), patch.object(control, 'nmcli') as cli:
                control.run([op, UUID])
                cli.assert_called_once_with('connection', op, 'uuid', UUID)

    def test_import_path_is_one_argument(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'Work $(never execute); profile.conf'
            path.write_text('test fixture, no secrets')
            with patch.object(control, 'profiles', return_value=[]), patch.object(control, 'nmcli') as cli:
                control.run(['import', path.as_uri()])
                cli.assert_called_once_with('connection', 'import', 'type', 'wireguard', 'file', str(path))
        for location in ('https://example.org/vpn.conf', 'file://remote/vpn.conf', 'file:///missing.conf'):
            with self.assertRaises(control.ControlError):
                control.run(['import', location])

    def test_missing_nmcli_and_timeouts(self):
        for failure in (FileNotFoundError(), subprocess.TimeoutExpired(['nmcli'], 35)):
            with patch.object(subprocess, 'run', side_effect=failure), self.assertRaises(control.ControlError):
                control.profiles()

    def test_permission_and_activation_errors(self):
        for code, error, expected in ((1, 'Not authorized', 'Нет прав'), (4, 'failed', 'Не удалось подключить'),
                                      (8, 'stopped', 'не запущен')):
            result = subprocess.CompletedProcess([], code, '', error)
            with patch.object(subprocess, 'run', return_value=result), self.assertRaisesRegex(control.ControlError, expected):
                control.profiles()


FAKE_NMCLI = '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
state = pathlib.Path(os.environ['NAYORI_WG_STATE'])
args = sys.argv[1:]
with open(str(state) + '.calls', 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args == ['monitor']:
    while True:
        time.sleep(0.1)
        event = pathlib.Path(str(state) + '.event')
        if event.exists():
            event.unlink()
            print('changed', flush=True)
data = json.loads(state.read_text())
if 'up' in args or 'down' in args:
    if data.get('fail'):
        print('activation failed', file=sys.stderr)
        sys.exit(4)
    data['active'] = 'up' in args
    time.sleep(0.1)
    state.write_text(json.dumps(data))
elif 'import' in args:
    data['imported'] = True
    state.write_text(json.dumps(data))
elif 'show' in args:
    if data.get('unavailable'):
        sys.exit(8)
    if data.get('empty'):
        sys.exit(0)
    print('Work\\\\: VPN:11111111-1111-4111-8111-111111111111:wireguard:' +
          ('yes:activated:wg0' if data.get('active') else 'no::'))
    if data.get('imported'):
        print('Imported:22222222-2222-4222-8222-222222222222:wireguard:no::')
    print('wifi:33333333-3333-4333-8333-333333333333:802-11-wireless:yes:activated:wlan0')
'''


def smoke():
    with tempfile.TemporaryDirectory(prefix='nayori-wireguard-') as folder:
        directory = Path(folder)
        cli = directory / 'nmcli'
        cli.write_text(FAKE_NMCLI)
        cli.chmod(0o755)
        state = directory / 'state.json'
        state.write_text(json.dumps({'active': False}))
        config = directory / 'Example profile.conf'
        config.write_text('fixture, never sent to real NetworkManager')
        env = dict(os.environ, PATH=str(directory) + os.pathsep + os.environ['PATH'],
                   NAYORI_WG_STATE=str(state), NAYORI_WG_IMPORT=config.as_uri(),
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   QT_QPA_PLATFORMTHEME='basic', QS_DISABLE_FILE_WATCHER='1',
                   XDG_RUNTIME_DIR=folder)
        result = subprocess.run(['qs', '-p', str(ROOT / 'tests/smoke/WireGuardSmoke.qml'), '--no-color'],
                                capture_output=True, text=True, env=env, timeout=20)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'WIREGUARD_PASS' in output, output
        assert not any(error in output for error in ('TypeError', 'ReferenceError', 'Unable to assign',
                                                     'Binding loop', 'Failed to load')), output
        calls = [json.loads(line) for line in Path(str(state) + '.calls').read_text().splitlines()]
        assert sum('up' in call for call in calls) == 2, calls
        assert sum('down' in call for call in calls) == 1, calls
        assert sum('import' in call for call in calls) == 1, calls
        state.write_text(json.dumps({'active': True, 'imported': True}))
        result = subprocess.run(['qs', '-p', str(ROOT / 'tests/smoke/NetworkPanelSmoke.qml'), '--no-color'],
                                capture_output=True, text=True, env=env, timeout=20)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and 'NETWORK_PANEL_PASS' in output, output
        assert not any(error in output for error in ('TypeError', 'ReferenceError', 'Unable to assign',
                                                     'Binding loop', 'Failed to load')), output


if __name__ == '__main__':
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(HelperTests))
    if not result.wasSuccessful():
        raise SystemExit(1)
    if '--unit' not in sys.argv:
        smoke()
    print('WIREGUARD_TESTS_PASS')
