"""Authentication view, backend loading, SDDM data and installation checks.

No real screen is locked and no display-manager service is changed.
SDDM_GREETER can point to an unpacked sddm-greeter-qt6 for test-mode checks.
"""
import importlib.util
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('login_theme', ROOT / 'services/lock/login_theme.py')
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


def run(command, env, marker, timeout=15, expected_timeout=False):
    try:
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b'').decode() + (error.stderr or b'').decode()
        if not expected_timeout:
            raise AssertionError(output) from error
        result = subprocess.CompletedProcess(command, 0, output, '')
    output = result.stdout + result.stderr
    assert result.returncode == 0 and marker in output, output
    for error in ('ReferenceError', 'TypeError', 'Unable to assign', 'Binding loop',
                  'Failed to load configuration', 'Fallback to embedded theme'):
        assert error not in output, output
    return output


def main():
    with tempfile.TemporaryDirectory(prefix='nayori-auth-') as temporary:
        base = Path(temporary)
        runtime = base / 'runtime'
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
                   XDG_CONFIG_HOME=str(base / 'config'), XDG_DATA_HOME=str(base / 'data-home'),
                   NAYORI_TEST_EXPORT=str(base / 'export'),
                   QT_QPA_PLATFORMTHEME='basic', QT_QUICK_BACKEND='software',
                   QS_DISABLE_FILE_WATCHER='1', QT_FORCE_STDERR_LOGGING='1')
        for name in ('NIRI_SOCKET', 'WAYLAND_DISPLAY', 'DISPLAY'):
            env.pop(name, None)
        for name, marker in [('AuthSmoke', 'AUTH_SMOKE_PASS'), ('AuthMotionSmoke', 'AUTH_MOTION_SMOKE_PASS'), ('LockServiceSmoke', 'LOCK_SERVICE_SMOKE_PASS'), ('LoginThemeSmoke', 'LOGIN_THEME_SMOKE_PASS')]:
            run(['qs', '-p', str(ROOT / f'tests/smoke/{name}.qml'), '--no-color'], env, marker)
            print(f'PASS {name}')
        colors = dict(zip(exporter.COLOR_KEYS, ['#172626', '#3D5650', '#293E38', '#F1EDE3', '#CED8D1', '#81C8BE', '#102724', '#57F1EDE3']))
        source = ROOT / 'assets/wallpapers/nayori.png'
        payload = dict(colors=colors, primaryOutput='DP-1',
                       wallpaper=dict(source=source.as_uri(), mode='fill'),
                       wallpapers={'DP-1': dict(source=source.as_uri(), mode='fit'),
                                   'HDMI-A-1': dict(source=source.as_uri(), mode='center')})
        target = base / 'data'
        exporter.publish(payload, target)
        original = (target / 'theme.conf.user').read_bytes()
        assert '81C8BE' in original.decode()
        assert len(list(target.glob('*.png'))) == 1, 'deduplicate shared wallpaper'
        assert not str(source).encode() in original, 'no dependency on home directory'
        assert all(path.stat().st_mode & 0o444 == 0o444 for path in target.iterdir())
        invalid = json.loads(json.dumps(payload))
        invalid['wallpaper']['source'] = 'https://example.com/wallpaper.png'
        try:
            exporter.publish(invalid, target)
            raise AssertionError('remote wallpaper accepted')
        except ValueError:
            pass
        assert (target / 'theme.conf.user').read_bytes() == original, 'failed publish must preserve last good snapshot'
        payload['colors']['accent'] = '#E5C890'
        exporter.publish(payload, target)
        assert 'E5C890' in (target / 'theme.conf.user').read_text()
        synced = base / 'synced'
        exporter.sync_snapshot(target, synced)
        assert synced.as_uri() in (synced / 'theme.conf.user').read_text()
        assert target.as_uri() not in (synced / 'theme.conf.user').read_text()
        assert list(synced.glob('*.png'))
        print('PASS palette/wallpaper export, two outputs, atomic failure and theme update')

        stage = base / 'install'
        command = ['python3', str(ROOT / 'scripts/install-sddm.py'), '--owner', pwd.getpwuid(os.getuid()).pw_name,
                   '--root', str(stage), '--select-theme']
        run(command, env, 'No services were started')
        installed = stage / 'usr/share/sddm/themes/nayori'
        assert (installed / 'components/AuthView.qml').is_file()
        assert (installed / 'wallpaper.png').is_file()
        assert (installed / 'theme.conf.user').readlink() == Path('/var/lib/nayori-sddm/theme.conf.user')
        run(command, env, 'No services were started')
        assert list(installed.parent.glob('nayori.bak-*')), 'preserve previous installation'
        print('PASS staged installation and backups')

        greeter = os.environ.get('SDDM_GREETER') or shutil.which('sddm-greeter-qt6') or shutil.which('sddm-greeter')
        if greeter:
            theme = base / 'theme'
            shutil.copytree(ROOT / 'sddm/nayori', theme)
            exporter.publish(payload, theme)
            main = theme / 'Main.qml'
            # Instrument only the disposable test copy, with real SDDM context models.
            checks = '''
    Timer {
        interval: 1000; running: true
        onTriggered: {
            if (palette.accent.toString() !== "#e5c890") throw new Error("SDDM dynamic palette")
            if (root.wallpaperData["DP-1"].mode !== "fit") throw new Error("SDDM wallpaper map")
            if (!view.primary) throw new Error("SDDM primary fallback")
            if (!view.loginMode) throw new Error("SDDM login view")
            if (!view.selectedLogin) throw new Error("SDDM selected user")
            console.log("SDDM_THEME_PASS")
            Qt.quit()
        }
    }
'''
            text = main.read_text()
            main.write_text(text[:text.rfind('}')] + checks + '}\n')
            run([greeter, '--test-mode', '--theme', str(theme)], env, 'SDDM_THEME_PASS', timeout=3, expected_timeout=True)
            print('PASS real SDDM greeter, config quoting and dynamic colors')
        else:
            print('SKIP real SDDM greeter (set SDDM_GREETER to enable)')


if __name__ == '__main__':
    main()
