"""Exercise ext-session-lock in a disposable nested Niri, never the host session."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check_case(parent_display, allow):
    with tempfile.TemporaryDirectory(prefix='nayori-lock-protocol-') as temporary:
        base = Path(temporary)
        runtime = base / 'runtime'
        runtime.mkdir(mode=0o700)
        config = base / 'config.kdl'
        config.write_text('input { keyboard { xkb { layout "us,ru"; options "grp:alt_shift_toggle"; }; }; }\n')
        case = base / 'shell'
        case.mkdir()
        for name in ('services', 'surfaces', 'sddm', 'tokens', 'assets'):
            (case / name).symlink_to(ROOT / name)
        (case / 'shell.qml').write_text((ROOT / 'tests/smoke/LockProtocolSmoke.qml').read_text())
        # Disposable PAM conversation with a synthetic token; production PAM is
        # neither modified nor invoked. pam_exec requests a password from the UI.
        helper = base / 'verify.py'
        helper.write_text('import sys\nvalue = sys.stdin.buffer.read().rstrip(b"\\0")\n'
                          f'sys.exit(0 if value == b"nayori-test-only" and {allow!r} else 1)\n')
        (case / 'pam').mkdir()
        (case / 'pam/nayori-lock').write_text(f'auth required pam_exec.so expose_authtok /usr/bin/python3 {helper}\n')
        env = dict(os.environ, WAYLAND_DISPLAY=parent_display, XDG_RUNTIME_DIR=str(runtime),
                   QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='basic',
                   NAYORI_LOCK_NESTED_TEST='1',
                   NAYORI_LOCK_TEST_ALLOW='1' if allow else '0',
                   QT_QUICK_BACKEND='software', LIBGL_ALWAYS_SOFTWARE='1',
                   NIRI_DISABLE_SYSTEM_MANAGER_NOTIFY='1')
        env.pop('DISPLAY', None)
        env.pop('NIRI_SOCKET', None)
        env.pop('QS_DISABLE_FILE_WATCHER', None)
        client_log = base / 'client.log'
        command = ['niri', '-c', str(config), '--', 'sh', '-c', 'exec qs -p "$1" --no-color >"$2" 2>&1',
                   'nayori-lock-test', str(case / 'shell.qml'), str(client_log)]
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
        try:
            try:
                output, _ = process.communicate(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                output, _ = process.communicate(timeout=4)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        output += client_log.read_text() if client_log.exists() else '\nNo test client log'
        assert 'LOCK_PROTOCOL_PASS' in output, output
        assert not any(error in output for error in ('TypeError', 'ReferenceError', 'Unable to assign', 'Failed to load configuration')), output
        print('PASS nested ext-session-lock / PAM ' + ('success' if allow else 'failure'))


def main():
    parent_display = os.environ.get('WAYLAND_DISPLAY')
    if not parent_display:
        raise SystemExit('A parent Wayland display is required for the nested test')
    if not parent_display.startswith('/'):
        parent_display = str(Path(os.environ['XDG_RUNTIME_DIR']) / parent_display)
    for allow in (False, True):
        check_case(parent_display, allow)


if __name__ == '__main__':
    main()
