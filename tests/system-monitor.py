#!/usr/bin/env python3
"""Deterministic telemetry tests; no host commands or config writes."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('system_monitor', Path(__file__).resolve().parents[1] / 'services/system/system_monitor.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MonitorTest(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.proc, self.sys = self.root / 'proc', self.root / 'sys'
        self.calls = []
        self.monitor = module.Monitor(self.proc, self.sys, self.command,
                                      lambda _: SimpleNamespace(f_blocks=100, f_frsize=1024, f_bfree=30, f_bavail=20))

    def command(self, args):
        self.calls.append(args)
        return ''

    def put(self, path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)

    def test_missing_sources_are_unknown(self):
        data = self.monitor.snapshot(1)
        self.assertIsNone(data['memory']['used'])
        self.assertIsNone(data['cpu']['threads'])
        self.assertIsNone(data['uptime'])
        self.assertEqual(data['gpus'], [])
        self.assertEqual(data['temperatures'], [])
        self.assertEqual(data['disks'], [])

    def test_memory_and_cpu(self):
        self.put(self.proc / 'meminfo', 'MemTotal: 1000 kB\nMemAvailable: 250 kB\n')
        self.put(self.proc / 'cpuinfo', 'processor: 0\nphysical id: 0\ncore id: 0\nmodel name: Fixture CPU\n\nprocessor: 1\nphysical id: 0\ncore id: 0\n')
        self.put(self.proc / 'uptime', '1234.5 4567')
        self.put(self.sys / 'devices/system/cpu/cpu0/cpufreq/scaling_cur_freq', '3000000')
        frame = self.monitor.snapshot(1)
        self.assertEqual(frame['memory']['used'], 750 * 1024)
        self.assertEqual(frame['cpu']['cores'], 1)
        self.assertEqual(frame['cpu']['threads'], 2)
        self.assertEqual(frame['cpu']['ghz'], 3)
        self.assertEqual(frame['uptime'], 1234.5)
        self.put(self.proc / 'meminfo', 'MemTotal: 1000 kB')
        self.assertIsNone(self.monitor.memory()['used'])

    def test_partition_io_and_reserved_space(self):
        self.put(self.proc / 'self/mountinfo', '1 0 8:1 / / rw - ext4 /dev/sda1 rw\n2 0 0:30 / /home rw - btrfs /dev/sdb rw\n3 0 8:2 / /media/a\\040b rw - ext4 /dev/sda2 rw\n')
        self.put(self.proc / 'diskstats', '8 0 sda 0 0 900 0 0 0 900 0 0 0 0\n8 1 sda1 0 0 10 0 0 0 20 0 0 0 0\n')
        disks = self.monitor.disks(1)
        self.assertEqual(disks[0]['used'], 70 * 1024)
        self.assertEqual(disks[0]['available'], 20 * 1024)
        self.assertIsNone(disks[0]['read'])
        self.assertEqual(disks[2]['mount'], '/media/a b')
        self.put(self.proc / 'diskstats', '8 1 sda1 0 0 14 0 0 0 28 0 0 0 0\n')
        disks = self.monitor.disks(3)
        self.assertEqual(disks[0]['read'], 1024)
        self.assertEqual(disks[0]['write'], 2048)
        self.assertEqual(disks[0]['ioDevice'], 'sda1')
        self.assertIsNone(disks[1]['read'])  # no invented mapping for btrfs

    def test_counter_reset_hotplug_and_interface_isolation(self):
        self.put(self.proc / 'net/dev', 'eth0: 100 0 0 0 0 0 0 0 200 0 0 0 0 0 0 0\n')
        self.assertIsNone(self.monitor.snapshot(1)['network'][0]['down'])
        self.put(self.proc / 'net/dev', 'eth0: 300 0 0 0 0 0 0 0 400 0 0 0 0 0 0 0\n')
        self.assertEqual(self.monitor.snapshot(3)['network'][0]['down'], 100)
        self.put(self.proc / 'net/dev', 'eth0: 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0\n')
        self.assertIsNone(self.monitor.snapshot(4)['network'][0]['down'])
        self.put(self.proc / 'net/dev', '')
        self.monitor.snapshot(5)
        self.assertEqual(self.monitor.previous, {})
        self.put(self.proc / 'net/dev', 'eth0: 9 0 0 0 0 0 0 0 9 0 0 0 0 0 0 0\n')
        self.assertIsNone(self.monitor.snapshot(6)['network'][0]['down'])

    def test_multiple_gpus_temperatures_and_partial_failure(self):
        for index, vendor in enumerate(['0x1002', '0x8086']):
            device = self.sys / 'devices' / f'0000:0{index}:00.0'
            device.mkdir(parents=True)
            card = self.sys / 'class/drm' / f'card{index}'
            card.mkdir(parents=True)
            (card / 'device').symlink_to(device)
            self.put(device / 'vendor', vendor)
        self.put(self.sys / 'devices/0000:00:00.0/gpu_busy_percent', '37')
        self.put(self.sys / 'class/hwmon/hwmon0/name', 'coretemp')
        self.put(self.sys / 'class/hwmon/hwmon0/temp1_input', '44000')
        frame = self.monitor.snapshot(1)
        self.assertEqual(frame['gpus'][0]['load'], 37)
        self.assertIsNone(frame['gpus'][1]['load'])
        self.assertEqual(frame['temperatures'][0]['value'], 44)
        self.monitor.gpus = lambda: (_ for _ in ()).throw(OSError('unplugged'))
        self.assertIsNone(self.monitor.snapshot(2)['gpus'])
        self.assertEqual(self.monitor.snapshot(2)['temperatures'][0]['value'], 44)

    def test_nvidia_pci_mapping_and_unknown_fields(self):
        device = self.sys / 'devices/0000:01:00.0'
        device.mkdir(parents=True)
        card = self.sys / 'class/drm/card0'
        card.mkdir(parents=True)
        (card / 'device').symlink_to(device)
        self.put(device / 'vendor', '0x10de')
        self.monitor.runner = lambda args: '00000000:01:00.0, RTX Fixture, 49, 42, 1024, 8192' if args[0] == 'nvidia-smi' else ''
        gpu = self.monitor.gpus()[0]
        self.assertEqual(gpu['model'], 'RTX Fixture')
        self.assertEqual(gpu['load'], 49)
        self.assertEqual(gpu['used'], 1024**3)
        self.monitor.runner = lambda args: '00000000:01:00.0, RTX Fixture, N/A, N/A, N/A, N/A' if args[0] == 'nvidia-smi' else ''
        self.assertIsNone(self.monitor.gpus()[0]['load'])
        self.assertIsNone(self.monitor.gpus()[0]['temperature'])

    def test_wireguard_without_networkmanager_and_default_interface(self):
        self.monitor.runner = lambda args: '[{"ifname":"wg0","linkinfo":{"info_kind":"wireguard"}}]' if args[0] == 'ip' else ''
        self.put(self.proc / 'net/dev', 'eth0: 100 0 0 0 0 0 0 0 200 0 0 0 0 0 0 0\nwg0: 10 0 0 0 0 0 0 0 20 0 0 0 0 0 0 0\n')
        self.put(self.proc / 'net/route', 'wg0 00000000 00000000 0001 0 0 0 0\n')
        network = self.monitor.snapshot(1)['network']
        self.assertEqual(network[0]['id'], 'wg0')
        self.assertTrue(network[0]['tunnel'])
        self.assertFalse(network[1]['tunnel'])

    def test_slow_commands_cached(self):
        self.monitor.snapshot(1)
        self.monitor.snapshot(2)
        self.assertEqual(sum(args[0] == 'powerprofilesctl' for args in self.calls), 1)
        self.monitor.snapshot(17)
        self.assertEqual(sum(args[0] == 'powerprofilesctl' for args in self.calls), 2)


if __name__ == '__main__':
    unittest.main()
