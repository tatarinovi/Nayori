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
        ipc('view','true'); ipc('view','false'); ipc('advance',10)
        assert state()['current'] is None and state()['unread']==0
        notify(nid,'Updated'); time.sleep(.1)
        assert state()['records'][0]['summary']=='Updated' and state()['current'] is None
        fresh=notify(title='Remove'); time.sleep(.1); ipc('remove',fresh); time.sleep(.1)
        assert all(r['id']!=fresh for r in state()['records'])
        print('NOTIFICATION_BRIDGE_PASS')
    finally:
        bridge.terminate(); bridge.wait(timeout=5)
        print(pathlib.Path(log.name).read_text())
