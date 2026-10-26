"""Send only Ctrl+V via Wayland virtual-keyboard v1; never read user input.

Small fixed protocol client, with a three-second deadline and no root daemon or
new package dependency. Failure leaves the already-copied clipboard untouched.
Protocol: https://github.com/atx/wtype/blob/master/protocol/virtual-keyboard-unstable-v1.xml
"""
import array
import os
from pathlib import Path
import socket
import struct
import sys
import time


KEYMAP = b'''xkb_keymap {
 xkb_keycodes { include "evdev+aliases(qwerty)" };
 xkb_types { include "complete" };
 xkb_compatibility { include "complete" };
 xkb_symbols { include "pc+us+inet(evdev)" };
};\n\0'''


def uints(*values):
    return struct.pack("=" + "I" * len(values), *values)


def string(value):
    data = value.encode() + b"\0"
    return uints(len(data)) + data + b"\0" * (-len(data) % 4)


class Wayland:
    def __init__(self, path):
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.settimeout(2)
        self.socket.connect(path)
        self.buffer = bytearray()
        self.next_id = 3
        self.globals = {}

    def send(self, identity, opcode, payload=b"", fd=None):
        packet = uints(identity, ((8 + len(payload)) << 16) | opcode) + payload
        if fd is None:
            self.socket.sendall(packet)
        else:
            sent = self.socket.sendmsg([packet], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", [fd]))])
            if sent < len(packet):
                self.socket.sendall(packet[sent:])

    def roundtrip(self):
        callback = self.next_id
        self.next_id += 1
        self.send(1, 0, uints(callback))  # wl_display.sync
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            if len(self.buffer) < 8:
                data = self.socket.recv(65536)
                if not data:
                    raise OSError("Wayland disconnected")
                self.buffer.extend(data)
                continue
            identity, word = struct.unpack_from("=II", self.buffer)
            size, opcode = word >> 16, word & 0xFFFF
            if not 8 <= size <= 65536:
                raise OSError("Invalid Wayland message")
            if len(self.buffer) < size:
                self.buffer.extend(self.socket.recv(65536))
                continue
            payload = bytes(self.buffer[8:size])
            del self.buffer[:size]
            if identity == 1 and opcode == 0:
                length = struct.unpack_from("=I", payload, 8)[0]
                reason = payload[12:12 + length - 1].decode(errors="replace")
                raise OSError("Compositor rejected virtual keyboard: " + reason)
            if identity == 2 and opcode == 0:  # wl_registry.global
                name, length = struct.unpack_from("=II", payload)
                interface = payload[8:8 + length - 1].decode()
                self.globals.setdefault(interface, name)
            if identity == callback and opcode == 0:
                return
        raise TimeoutError("Wayland did not acknowledge the shortcut")

    def bind(self, interface, identity):
        if interface not in self.globals:
            raise OSError("Compositor does not support " + interface)
        self.send(2, 0, uints(self.globals[interface]) + string(interface) + uints(1, identity))


def paste():
    display = os.environ.get("WAYLAND_DISPLAY", "")
    if not display:
        raise OSError("No Wayland session")
    path = display if display.startswith("/") else str(Path(os.environ["XDG_RUNTIME_DIR"]) / display)
    connection = Wayland(path)
    try:
        connection.send(1, 1, uints(2))  # wl_display.get_registry
        connection.roundtrip()
        connection.bind("wl_seat", 4)
        connection.bind("zwp_virtual_keyboard_manager_v1", 5)
        connection.send(5, 0, uints(4, 6))  # manager.create_virtual_keyboard(seat, id)
        connection.next_id = 7
        fd = os.memfd_create("nayori-paste-keymap", os.MFD_CLOEXEC)
        try:
            os.write(fd, KEYMAP)
            connection.send(6, 0, uints(1, len(KEYMAP)), fd=fd)
            connection.roundtrip()
        finally:
            os.close(fd)
        timestamp = int(time.monotonic() * 1000) & 0xFFFFFFFF
        connection.send(6, 2, uints(4, 0, 0, 0))  # Control depressed
        connection.send(6, 1, uints(timestamp, 47, 1))  # evdev KEY_V, pressed
        connection.send(6, 1, uints(timestamp, 47, 0))
        connection.send(6, 2, uints(0, 0, 0, 0))  # Always release the modifier.
        connection.roundtrip()
        connection.send(6, 3)  # virtual_keyboard.destroy
        connection.roundtrip()
    finally:
        connection.socket.close()


if __name__ == "__main__":
    try:
        paste()
    except (OSError, KeyError, TimeoutError) as failure:
        print(str(failure), file=sys.stderr)
        raise SystemExit(1)
