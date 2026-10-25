#!/usr/bin/env python3
"""Run under dbus-run-session; never uses the desktop bus."""
import json, os, pathlib, subprocess, tempfile, time
root = pathlib.Path(__file__).resolve().parents[1]
env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='basic', QT_QUICK_BACKEND='software')
with tempfile.TemporaryDirectory(prefix='nayori-host-test-') as directory:
    env['XDG_RUNTIME_DIR'] = directory
    os.chmod(directory, 0o700)
    log = open(directory + '/host.log', 'w+')
    host = subprocess.Popen(['qs', '-p', str(root/'services/island/NotificationHost.qml'), '--no-color'], env=env, stdout=log, stderr=subprocess.STDOUT)
    def call(interface, method, signature, *args):
        return subprocess.check_output(['busctl','--user','call','org.freedesktop.Notifications','/org/freedesktop/Notifications',interface,method,signature,*map(str,args)],env=env,text=True).strip()
    def events():
        log.flush(); log.seek(0)
        return [json.loads(line.split('NAYORI_EVENT ',1)[1]) for line in log if 'NAYORI_EVENT ' in line]
    try:
        for _ in range(80):
            if any(e['type']=='ready' for e in events()): break
            if host.poll() is not None: raise RuntimeError(pathlib.Path(log.name).read_text())
            time.sleep(.05)
        else: raise RuntimeError('host did not register')
        result=call('org.freedesktop.Notifications','Notify','susssasa{sv}i','Test',0,'','First','Body',0,0,0)
        nid=int(result.split()[1]); time.sleep(.1)
        call('org.freedesktop.Notifications','Notify','susssasa{sv}i','Test',nid,'','Updated','Second',0,0,0); time.sleep(.1)
        call('org.freedesktop.Notifications','CloseNotification','u',nid); time.sleep(.1)
        stream=events()
        assert any(e.get('summary')=='Updated' for e in stream), stream
        assert any(e['type']=='closed' and e['id']==nid for e in stream), stream
        busy=subprocess.run(['qs','-p',str(root/'services/island/NotificationHost.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=5)
        assert 'Сервис уведомлений занят' in busy.stdout+busy.stderr, busy.stdout+busy.stderr
        assert host.poll() is None
        # Simulate another daemon winning between preflight and registration.
        stub = pathlib.Path(directory) / 'bin'; stub.mkdir()
        (stub/'busctl').write_text("#!/usr/bin/env python3\nimport os,sys\nif 'NameHasOwner' in sys.argv: print('b false')\nelse: os.execv('/usr/bin/busctl', ['busctl']+sys.argv[1:])\n")
        (stub/'busctl').chmod(0o755)
        race_env = dict(env, PATH=str(stub)+':'+env['PATH'])
        race=subprocess.run(['qs','-p',str(root/'services/island/NotificationHost.qml'),'--no-color'],env=race_env,capture_output=True,text=True,timeout=5)
        assert 'Не удалось занять сервис' in race.stdout+race.stderr, race.stdout+race.stderr
        owner=subprocess.check_output(['busctl','--user','call','org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetConnectionUnixProcessID','s','org.freedesktop.Notifications'],env=env,text=True).strip()
        assert owner == f'u {host.pid}', owner
        result=call('org.freedesktop.Notifications','Notify','susssasa{sv}i','Test',0,'','Dismiss me','Body',0,0,0)
        dismissed=int(result.split()[1])
        subprocess.run(['qs','ipc','--pid',str(host.pid),'call','notifications','invoke',str(dismissed),'__dismiss'],env=env,check=True,capture_output=True,text=True)
        time.sleep(.1)
        assert any(e['type']=='closed' and e['id']==dismissed for e in events())
        print('NOTIFICATION_HOST_PASS')
    finally:
        host.terminate(); host.wait(timeout=5)
        print(pathlib.Path(log.name).read_text())
