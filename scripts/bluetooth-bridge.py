"""Event-driven BlueZ operations and a per-client pairing agent; JSON lines IPC."""
import json
import os
import sys

from gi.repository import Gio, GLib

AGENT_XML = '''<node><interface name="org.bluez.Agent1">
<method name="Release"/><method name="Cancel"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>'''


def emit(**data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


class Bridge:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.loop = GLib.MainLoop()
        self.agent = None
        self.serial = 0
        self.scan_path = None
        self.active = False
        self.input_buffer = b''
        self.pairing_path = None
        info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
        self.bus.register_object('/org/nayori/BluetoothAgent', info, self.agent_call, None, None)
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, self.read)

    def call(self, path, interface, method, args, done):
        def finished(bus, result):
            try:
                bus.call_finish(result)
                done(None)
            except GLib.Error as error:
                done(str(error))
        self.bus.call('org.bluez', path, interface, method, args, None,
                      Gio.DBusCallFlags.NONE, 90000, None, finished)

    def reject_agent(self):
        if self.agent:
            self.agent[1].return_dbus_error('org.bluez.Error.Rejected', 'Canceled by user')
            self.agent = None
        emit(event='agent', request=None)

    def agent_call(self, _bus, _sender, _path, _iface, method, params, invocation):
        values = params.unpack()
        if method in ('Release', 'Cancel'):
            self.reject_agent()
            invocation.return_value(None)
            return
        if not self.pairing_path or not values or values[0] != self.pairing_path:
            invocation.return_dbus_error('org.bluez.Error.Rejected', 'No pairing requested')
            return
        self.reject_agent()
        self.serial += 1
        display = method in ('DisplayPinCode', 'DisplayPasskey')
        code = str(values[1]) if method == 'DisplayPinCode' else f'{values[1]:06d}' if method in ('DisplayPasskey', 'RequestConfirmation') else ''
        emit(event='agent', request=dict(id=self.serial, method=method, device=values[0], code=code))
        if display:
            invocation.return_value(None)
        else:
            self.agent = (method, invocation, self.serial)

    def reply(self, command):
        if not self.agent or command.get('request') != self.agent[2]:
            return
        method, invocation, _serial = self.agent
        if not command.get('accept'):
            self.reject_agent()
            return
        value = str(command.get('value', ''))
        if method == 'RequestPasskey' and (not value.isdigit() or len(value) > 6):
            return
        if method == 'RequestPinCode' and not 1 <= len(value) <= 16:
            return
        self.agent = None
        result = GLib.Variant('(u)', (int(value),)) if method == 'RequestPasskey' else GLib.Variant('(s)', (value,)) if method == 'RequestPinCode' else None
        invocation.return_value(result)
        emit(event='agent', request=None)

    def stop_scan(self):
        if not self.scan_path:
            emit(event='scanStopped', error='')
            return
        path = self.scan_path

        def stopped(error):
            if not error:
                self.scan_path = None
            emit(event='scanStopped', error=error or '')
        self.call(path, 'org.bluez.Adapter1', 'StopDiscovery', None, stopped)

    def run_command(self, command):
        op = command.get('op')
        if op == 'stopScan':
            self.stop_scan()
            return
        if op == 'reply':
            self.reply(command)
            return
        ident = command.get('id')
        path = command.get('path', '')
        if not path.startswith('/org/bluez/') or self.active:
            emit(event='result', id=ident, error='Операция недоступна')
            return
        self.active = True

        def done(error):
            self.active = False
            self.pairing_path = None
            self.reject_agent()
            emit(event='result', id=ident, error=error or '')

        if op == 'power':
            def powered(_error=None):
                self.call(path, 'org.freedesktop.DBus.Properties', 'Set',
                          GLib.Variant('(ssv)', ('org.bluez.Adapter1', 'Powered', GLib.Variant('b', bool(command.get('value'))))), done)
            if not command.get('value') and self.scan_path:
                def stopped_before_power(error):
                    if error:
                        done(error)
                    else:
                        self.scan_path = None
                        powered()
                self.call(self.scan_path, 'org.bluez.Adapter1', 'StopDiscovery', None, stopped_before_power)
            else:
                powered()
        elif op == 'scan':
            def scanned(error):
                if not error:
                    self.scan_path = path
                done(error)
            self.call(path, 'org.bluez.Adapter1', 'StartDiscovery', None, scanned)
        elif op in ('connect', 'disconnect', 'pair'):
            def device_call(error=None):
                if error:
                    done(error)
                else:
                    self.call(path, 'org.bluez.Device1', {'connect': 'Connect', 'disconnect': 'Disconnect', 'pair': 'Pair'}[op], None, done)
            if op == 'pair':
                self.pairing_path = path
                # Register on this connection only; never replace the session's default agent.
                def registered(error):
                    if error and 'AlreadyExists' not in error:
                        done(error)
                    else:
                        device_call()
                self.call('/org/bluez', 'org.bluez.AgentManager1', 'RegisterAgent',
                          GLib.Variant('(os)', ('/org/nayori/BluetoothAgent', 'KeyboardDisplay')), registered)
            else:
                device_call()
        elif op == 'forget':
            adapter_path = path.rsplit('/', 1)[0]
            self.call(adapter_path, 'org.bluez.Adapter1', 'RemoveDevice', GLib.Variant('(o)', (path,)), done)
        else:
            done('Неизвестная операция Bluetooth')

    def read(self, source, _condition):
        chunk = os.read(source, 65536)
        if not chunk:
            # Dropping the bus connection releases this client's discovery session and agent.
            self.loop.quit()
            return False
        self.input_buffer += chunk
        while b'\n' in self.input_buffer:
            line, self.input_buffer = self.input_buffer.split(b'\n', 1)
            try:
                command = json.loads(line)
                if not isinstance(command, dict):
                    raise ValueError('Expected a JSON object')
                self.run_command(command)
            except (ValueError, TypeError, KeyError) as error:
                emit(event='result', id=None, error=str(error))
        return True


if __name__ == '__main__':
    try:
        Bridge().loop.run()
    except GLib.Error as error:
        emit(event='fatal', error=str(error))
        sys.exit(1)
