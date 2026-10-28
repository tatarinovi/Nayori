"""Exercise native Quickshell models, Agent1 and operations against an isolated BlueZ."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = '/org/bluez/hci0'
DEVICE = ADAPTER + '/dev_11_22_33_44_55_66'
XML = '''<node>
<interface name="org.freedesktop.DBus.ObjectManager"><method name="GetManagedObjects"><arg type="a{oa{sa{sv}}}" direction="out"/></method></interface>
<interface name="org.bluez.Adapter1">
<property name="Address" type="s" access="read"/><property name="Alias" type="s" access="read"/><property name="Name" type="s" access="read"/>
<property name="Powered" type="b" access="readwrite"/><property name="Discovering" type="b" access="read"/>
<property name="Discoverable" type="b" access="read"/><property name="Pairable" type="b" access="read"/>
<method name="StartDiscovery"/><method name="StopDiscovery"/><method name="RemoveDevice"><arg type="o" direction="in"/></method>
</interface>
<interface name="org.bluez.Device1">
<property name="Address" type="s" access="read"/><property name="Alias" type="s" access="read"/><property name="Name" type="s" access="read"/>
<property name="Icon" type="s" access="read"/><property name="Adapter" type="o" access="read"/>
<property name="Connected" type="b" access="read"/><property name="Paired" type="b" access="read"/><property name="Bonded" type="b" access="read"/>
<method name="Connect"/><method name="Disconnect"/><method name="Pair"/>
</interface>
<interface name="org.bluez.Battery1"><property name="Percentage" type="y" access="read"/></interface>
<interface name="org.bluez.AgentManager1"><method name="RegisterAgent"><arg type="o" direction="in"/><arg type="s" direction="in"/></method></interface>
</node>'''


def run():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                  'RequestName', GLib.Variant('(su)', ('org.bluez', 0)), None, Gio.DBusCallFlags.NONE, -1, None)
    objects = {
        ADAPTER: {'org.bluez.Adapter1': {key: GLib.Variant(kind, value) for key, kind, value in [
            ('Address', 's', '00:00:00:00:00:00'), ('Name', 's', 'Test adapter'), ('Alias', 's', 'Test adapter'),
            ('Powered', 'b', True), ('Discovering', 'b', False), ('Discoverable', 'b', False), ('Pairable', 'b', True)]}},
        DEVICE: {
            'org.bluez.Device1': {key: GLib.Variant(kind, value) for key, kind, value in [
                ('Address', 's', '11:22:33:44:55:66'), ('Alias', 's', 'Headphones'), ('Name', 's', 'Headphones'),
                ('Adapter', 'o', ADAPTER), ('Icon', 's', 'audio-headphones'), ('Connected', 'b', False),
                ('Paired', 'b', True), ('Bonded', 'b', True)]},
            'org.bluez.Battery1': {'Percentage': GLib.Variant('y', 42)}}}
    nearby = ADAPTER + '/dev_AA_BB_CC_DD_EE_FF'
    nearby_data = {'org.bluez.Device1': dict(objects[DEVICE]['org.bluez.Device1'])}
    nearby_data['org.bluez.Device1'].update({
        'Address': GLib.Variant('s', 'AA:BB:CC:DD:EE:FF'),
        'Alias': GLib.Variant('s', 'Nearby keyboard'),
        'Icon': GLib.Variant('s', 'input-keyboard'),
        'Paired': GLib.Variant('b', False), 'Bonded': GLib.Variant('b', False)})
    calls = []
    agent = []

    def change(path, interface, key, value):
        objects[path][interface][key] = value
        bus.emit_signal(None, path, 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                        GLib.Variant('(sa{sv}as)', (interface, {key: value}, [])))

    def method(_bus, sender, path, interface, name, params, invocation):
        calls.append(name)
        if name == 'GetManagedObjects':
            invocation.return_value(GLib.Variant('(a{oa{sa{sv}}})', (objects,)))
            return
        if name == 'RegisterAgent':
            agent[:] = [sender, params.unpack()[0]]
        elif name in ('StartDiscovery', 'StopDiscovery'):
            change(path, interface, 'Discovering', GLib.Variant('b', name == 'StartDiscovery'))
            if name == 'StartDiscovery' and nearby not in objects:
                objects[nearby] = nearby_data
                device_info = next(info for info in infos if info.name == 'org.bluez.Device1')
                bus.register_object(nearby, device_info, method, get_property, set_property)
                bus.emit_signal(None, '/', 'org.freedesktop.DBus.ObjectManager', 'InterfacesAdded',
                                GLib.Variant('(oa{sa{sv}})', (nearby, nearby_data)))
        elif name in ('Connect', 'Disconnect'):
            if name == 'Connect' and calls.count('Connect') > 1:
                def removed():
                    for object_path in [DEVICE, nearby, ADAPTER]:
                        bus.emit_signal(None, '/', 'org.freedesktop.DBus.ObjectManager', 'InterfacesRemoved',
                                        GLib.Variant('(oas)', (object_path, list(objects[object_path]))))
                    return False
                GLib.timeout_add(300, removed)
                invocation.return_dbus_error('org.bluez.Error.Failed', 'TestFailure')
                return
            change(path, interface, 'Connected', GLib.Variant('b', name == 'Connect'))
        elif name == 'Pair':
            def confirmed(connection, result):
                connection.call_finish(result)
                change(path, 'org.bluez.Device1', 'Paired', GLib.Variant('b', True))
                invocation.return_value(None)
            bus.call(agent[0], agent[1], 'org.bluez.Agent1', 'RequestConfirmation',
                     GLib.Variant('(ou)', (path, 123456)), None, Gio.DBusCallFlags.NONE, 10000, None, confirmed)
            return
        elif name == 'RemoveDevice':
            change(DEVICE, 'org.bluez.Device1', 'Paired', GLib.Variant('b', False))
            change(DEVICE, 'org.bluez.Device1', 'Bonded', GLib.Variant('b', False))
        invocation.return_value(None)

    def get_property(_bus, _sender, path, interface, name):
        return objects[path][interface][name]

    def set_property(_bus, _sender, path, interface, name, value):
        change(path, interface, name, value)
        return True

    infos = Gio.DBusNodeInfo.new_for_xml(XML).interfaces
    for info in infos:
        paths = ['/'] if info.name.endswith('ObjectManager') else ['/org/bluez'] if info.name.endswith('AgentManager1') else [p for p, data in objects.items() if info.name in data]
        for path in paths:
            bus.register_object(path, info, method, get_property, set_property)
    with tempfile.TemporaryDirectory(prefix='nayori-bluetooth-') as directory:
        env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ['DBUS_SESSION_BUS_ADDRESS'],
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   QT_QPA_PLATFORMTHEME='basic', QS_DISABLE_FILE_WATCHER='1', NAYORI_BT_SETTINGS=directory)
        with tempfile.TemporaryFile(mode='w+') as log:
            process = subprocess.Popen(['qs', '-p', str(ROOT / 'tests/smoke/BluetoothSmoke.qml'), '--no-color'],
                                       env=env, stdout=log, stderr=log)
            loop = GLib.MainLoop()
            def poll():
                if process.poll() is not None:
                    loop.quit()
                    return False
                return True
            GLib.timeout_add(50, poll)
            GLib.timeout_add_seconds(22, lambda: (process.kill(), loop.quit(), False)[-1])
            loop.run()
            process.wait(timeout=3)
            log.seek(0)
            output = log.read()
            assert process.returncode == 0 and 'BLUETOOTH_PASS' in output, output
            assert not any(word in output for word in ['TypeError', 'ReferenceError', 'Unable to assign', 'Failed to load', 'Binding loop']), output
        assert json.loads(Path(directory, 'settings.json').read_text())['bluetoothIconVisible'] is False
        assert calls.count('StartDiscovery') == 1 and calls.count('StopDiscovery') == 1, calls
        assert all(name in calls for name in ['Connect', 'Disconnect', 'Pair', 'RemoveDevice', 'RegisterAgent']), calls
        print('PASS Bluetooth: native models, battery, operations, discovery, pairing agent, errors, persistence')


if __name__ == '__main__':
    run()
