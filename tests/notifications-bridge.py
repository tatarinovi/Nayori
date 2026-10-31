#!/usr/bin/env python3
"""Exercise host -> bridge -> shared model and action dispatch on a private bus."""
import json, os, pathlib, subprocess, tempfile, time
root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='nayori-bridge-test-') as directory:
    os.chmod(directory,0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='basic',QT_QUICK_BACKEND='software',NAYORI_ISLAND_NOTIFICATION_TEST='1')
    log=open(directory+'/bridge.log','w+')
    bridge=subprocess.Popen(['qs','-p',str(root/'tests/smoke/NotificationBridgeSmoke.qml'),'--no-color'],env=env,stdout=log,stderr=subprocess.STDOUT)
    def ipc(method,*args):
        return subprocess.check_output(['qs','ipc','--pid',str(bridge.pid),'call','test',method,*map(str,args)],env=env,text=True,stderr=subprocess.DEVNULL).strip()
    def state(): return json.loads(ipc('state'))
    def notify(replace=0,title='First'):
        result=subprocess.check_output(['busctl','--user','call','org.freedesktop.Notifications','/org/freedesktop/Notifications','org.freedesktop.Notifications','Notify','susssasa{sv}i','Test',str(replace),'',title,'Body','0','0','0'],env=env,text=True)
        return int(result.split()[1])
    try:
        for _ in range(80):
            try:
                if state()['available']: break
            except (subprocess.CalledProcessError,ValueError): pass
            if bridge.poll() is not None: raise RuntimeError(pathlib.Path(log.name).read_text())
            time.sleep(.05)
        else: raise RuntimeError('bridge not ready: '+str(state()))
        nid=notify(); time.sleep(.1)
        assert state()['current']['id']==nid and state()['unread']==1
        ipc('view','true'); ipc('view','false')
        assert state()['current'] is None and state()['unread']==1
        ipc('markRead',nid)
        assert state()['unread']==0
        notify(nid,'Updated'); time.sleep(.1)
        assert state()['records'][0]['summary']=='Updated' and state()['current'] is None
        fresh=notify(title='Remove'); time.sleep(.1); ipc('remove',fresh); time.sleep(.1)
        assert all(r['id']!=fresh for r in state()['records'])
        ipc('setEnabled', 'false')
        for _ in range(80):
            if not state().get('running'): break
            time.sleep(.05)
        else: raise RuntimeError('host did not stop: '+str(state()))
        stopped = state()
        assert stopped['running'] is False and stopped['available'] is False and stopped['diagnostic'] == '', stopped
        for _ in range(40):
            owner = subprocess.run(['busctl','--user','call','org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','NameHasOwner','s','org.freedesktop.Notifications'], env=env, capture_output=True, text=True)
            if owner.stdout.strip() == 'b false': break
            time.sleep(.05)
        else: raise RuntimeError('name stayed taken: '+owner.stdout+' '+owner.stderr)
        other = subprocess.Popen(['qs','-p',str(root/'services/island/NotificationHost.qml'),'--no-color'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            for _ in range(80):
                if other.poll() is not None: raise RuntimeError('competing host exited')
                owner = subprocess.run(['busctl','--user','call','org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetConnectionUnixProcessID','s','org.freedesktop.Notifications'], env=env, capture_output=True, text=True)
                if owner.stdout.strip() == f'u {other.pid}': break
                time.sleep(.05)
            else: raise RuntimeError('competing host did not own the name')
            ipc('setEnabled', 'true')
            for _ in range(80):
                current = state()
                if 'занят' in current.get('diagnostic',''): break
                if bridge.poll() is not None: raise RuntimeError(pathlib.Path(log.name).read_text())
                time.sleep(.05)
            else: raise RuntimeError('missing busy error: '+str(state()))
            conflict = state()
            assert conflict['available'] is False and conflict['running'] is False, conflict
            owner = subprocess.check_output(['busctl','--user','call','org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetConnectionUnixProcessID','s','org.freedesktop.Notifications'], env=env, text=True).strip()
            assert owner == f'u {other.pid}', owner
        finally:
            other.terminate(); other.wait(timeout=5)
        print('NOTIFICATION_BRIDGE_PASS')
    finally:
        bridge.terminate(); bridge.wait(timeout=5)
        print(pathlib.Path(log.name).read_text())
