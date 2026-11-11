#!/usr/bin/env python3
"""Read-only Linux telemetry worker. One JSON snapshot/second while subscribed.

CPU utilisation is supplied by Nayori's existing Cpu.qml sampler, not duplicated.
Every source may fail independently; missing values are JSON null, never zero.
"""
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time


def read(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def number(path, scale=1):
    try:
        value = float(read(path)) / scale
        return value if math.isfinite(value) else None
    except ValueError:
        return None


def command(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=0.6,
                              check=False).stdout.strip()
    except (OSError, subprocess.SubprocessError, UnicodeError):
        return ""


def unescape(value):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), value)


class Monitor:
    def __init__(self, proc=Path('/proc'), sys=Path('/sys'), runner=command, statvfs=os.statvfs):
        self.proc, self.sys = Path(proc), Path(sys)
        self.runner, self.statvfs = runner, statvfs
        self.previous = {}
        self.slow = {}
        self.slow_at = -float('inf')
        self.details = False
        self.processes_at = -float('inf')
        self.processes = []
        self.gpu_names = {}
        self.tunnels = set()

    def rate(self, key, counters, now):
        old = self.previous.get(key)
        self.previous[key] = (now, counters)
        if old is None or now <= old[0] or any(a < b for a, b in zip(counters, old[1])):
            return [None] * len(counters)
        return [(a - b) / (now - old[0]) for a, b in zip(counters, old[1])]

    def cpu(self):
        blocks = read(self.proc / 'cpuinfo').split('\n\n')
        rows = [dict(line.split(':', 1) for line in block.splitlines() if ':' in line) for block in blocks]
        rows = [{k.strip(): v.strip() for k, v in row.items()} for row in rows if row]
        cores = {(r['physical id'], r['core id']) for r in rows if 'physical id' in r and 'core id' in r}
        frequencies = [number(p, 1000000) for p in (self.sys / 'devices/system/cpu').glob('cpu[0-9]*/cpufreq/scaling_cur_freq')]
        frequencies = [x for x in frequencies if x is not None]
        return {'model': rows[0].get('model name', rows[0].get('Processor', '')) if rows else '',
                'threads': len(rows) or None, 'cores': len(cores) or None,
                'ghz': sum(frequencies) / len(frequencies) if frequencies else None}

    def memory(self):
        values = {}
        for line in read(self.proc / 'meminfo').splitlines():
            fields = line.replace(':', '').split()
            if len(fields) >= 2 and fields[1].isdigit():
                values[fields[0]] = int(fields[1]) * 1024
        total, available = values.get('MemTotal'), values.get('MemAvailable')
        return {'total': total, 'used': total - available if total and available is not None and 0 <= available <= total else None}

    def temperatures(self):
        result = []
        for hw in (self.sys / 'class/hwmon').glob('hwmon*'):
            driver = read(hw / 'name')
            kind = 'cpu' if driver in ('coretemp', 'k10temp', 'zenpower', 'cpu_thermal') else 'ssd' if driver in ('nvme', 'drivetemp') else 'gpu' if driver in ('amdgpu', 'nouveau', 'i915', 'xe') else 'other'
            for p in hw.glob('temp*_input'):
                value = number(p, 1000)
                if value is not None and -50 < value < 200:
                    result.append({'id': str(p), 'kind': kind, 'label': read(p.with_name(p.name.replace('_input', '_label'))) or driver,
                                   'value': value})
        return result

    def disks(self, now):
        counters = {}
        for line in read(self.proc / 'diskstats').splitlines():
            f = line.split()
            if len(f) >= 14:
                try:
                    counters[f[0] + ':' + f[1]] = (f[2], [int(f[5]) * 512, int(f[9]) * 512])
                except ValueError:
                    pass
        rates = {key: self.rate('disk:' + key, row[1], now) for key, row in counters.items()}
        result = []
        for line in read(self.proc / 'self/mountinfo').splitlines():
            f = line.split()
            if '-' not in f or len(f) < 7:
                continue
            sep = f.index('-')
            if len(f) <= sep + 2:
                continue
            mount, fs, source = unescape(f[4]), f[sep + 1], unescape(f[sep + 2])
            if fs not in ('ext2', 'ext3', 'ext4', 'btrfs', 'xfs', 'f2fs', 'vfat', 'ntfs', 'ntfs3', 'zfs', 'bcachefs'):
                continue
            try:
                stat = self.statvfs(mount)
            except OSError:
                continue
            # mountinfo identifies the exact block device, including dm and partitions.
            # Multi-device filesystems do not have one truthful diskstats match.
            io = counters.get(f[2]) if fs not in ('btrfs', 'zfs', 'bcachefs') else None
            speed = rates.get(f[2], [None, None]) if io else [None, None]
            result.append({'id': mount, 'mount': mount, 'source': source, 'fs': fs,
                           'total': stat.f_blocks * stat.f_frsize,
                           'used': (stat.f_blocks - stat.f_bfree) * stat.f_frsize,
                           'available': stat.f_bavail * stat.f_frsize,
                           'ioDevice': io[0] if io else '', 'read': speed[0], 'write': speed[1]})
        return result

    def network(self, now):
        result = []
        for line in read(self.proc / 'net/dev').splitlines():
            if ':' not in line:
                continue
            name, data = line.split(':', 1)
            name, f = name.strip(), data.split()
            if name == 'lo' or len(f) < 16:
                continue
            try:
                down, up = self.rate('net:' + name, [int(f[0]), int(f[8])], now)
            except ValueError:
                continue
            path = self.sys / 'class/net' / name
            state = read(path / 'operstate')
            # Tunnel detection is evidence of a tunnel, not proof of a VPN route.
            tunnel = name in self.tunnels or (path / 'tun_flags').exists() or read(path / 'uevent').find('DEVTYPE=wireguard') >= 0
            result.append({'id': name, 'state': state, 'down': down, 'up': up,
                           'tunnel': tunnel})
        defaults = {f[0] for line in read(self.proc / 'net/route').splitlines()
                    if len(f := line.split()) > 3 and f[1] == '00000000' and int(f[3], 16) & 1}
        return sorted(result, key=lambda row: (row['id'] not in defaults, row['state'] != 'up', row['tunnel'], row['id']))

    def gpus(self):
        nv = {}
        cards = [card for card in sorted((self.sys / 'class/drm').glob('card[0-9]*'))
                 if re.fullmatch(r'card\d+', card.name) and (card / 'device').exists()]
        has_nvidia = any(read(card / 'device/vendor') == '0x10de' for card in cards)
        output = self.runner(['nvidia-smi', '--query-gpu=pci.bus_id,name,utilization.gpu,temperature.gpu,memory.used,memory.total', '--format=csv,noheader,nounits']) if has_nvidia else ''
        for line in output.splitlines():
            f = [x.strip() for x in line.split(',')]
            if len(f) != 6:
                continue
            def numeric(s, scale=1):
                try:
                    value = float(s) * scale
                    return value if math.isfinite(value) else None
                except ValueError:
                    return None
            # NVIDIA uses an eight-digit PCI domain; sysfs uses four.
            nv[f[0].lower()[-12:]] = {'model': f[1], 'load': numeric(f[2]), 'temperature': numeric(f[3]),
                                     'used': numeric(f[4], 1048576), 'total': numeric(f[5], 1048576)}
        result = []
        for card in cards:
            device = card / 'device'
            pci = device.resolve().name
            vendor = read(device / 'vendor')
            row = {'id': pci, 'model': '', 'load': number(device / 'gpu_busy_percent'),
                   'used': number(device / 'mem_info_vram_used'), 'total': number(device / 'mem_info_vram_total'),
                   'temperature': None}
            names = {'0x1002': 'AMD', '0x8086': 'Intel', '0x10de': 'NVIDIA'}
            row['model'] = names.get(vendor, 'GPU') + ' · ' + (read(device / 'device') or pci)
            # Kernel exposes a marketing name for some drivers. No privileged APIs.
            row['model'] = read(device / 'product_name') or self.gpu_names.get(pci.lower()) or row['model']
            temps = [number(p, 1000) for p in (device / 'hwmon').glob('hwmon*/temp1_input')]
            row['temperature'] = next((t for t in temps if t is not None), None)
            row.update(nv.get(pci.lower(), {}))
            if row['load'] is not None and not 0 <= row['load'] <= 100:
                row['load'] = None
            if row['temperature'] is not None and not -50 < row['temperature'] < 200:
                row['temperature'] = None
            if row['total'] is not None and row['total'] <= 0:
                row['total'] = row['used'] = None
            result.append(row)
        return result

    def snapshot(self, now=None):
        now = time.monotonic() if now is None else now
        if now - self.slow_at >= 15:
            self.gpu_names = {}
            for line in self.runner(['lspci', '-Dmm']).splitlines():
                try:
                    fields = shlex.split(line)
                    if len(fields) >= 4:
                        self.gpu_names[fields[0].lower()] = fields[2] + ' ' + fields[3]
                except ValueError:
                    continue
            self.tunnels = set()
            try:
                links = json.loads(self.runner(['ip', '-j', '-d', 'link', 'show']) or '[]')
                self.tunnels = {row['ifname'] for row in links if row.get('linkinfo', {}).get('info_kind') in ('wireguard', 'tun', 'tap', 'xfrm', 'vti', 'vti6')}
            except (ValueError, TypeError, KeyError):
                pass
        frame = {'time': now, 'errors': []}
        for name, probe in [('cpu', self.cpu), ('memory', self.memory), ('temperatures', self.temperatures),
                            ('gpus', self.gpus), ('disks', lambda: self.disks(now)), ('network', lambda: self.network(now))]:
            try:
                frame[name] = probe()
            except (OSError, ValueError, IndexError, KeyError) as error:
                frame[name] = None
                frame['errors'].append(name + ': ' + type(error).__name__)
        try:
            value = float(read(self.proc / 'uptime').split()[0])
            frame['uptime'] = value if math.isfinite(value) else None
        except (ValueError, IndexError):
            frame['uptime'] = None
        if now - self.slow_at >= 15:
            self.slow = {'profile': self.runner(['powerprofilesctl', 'get']),
                         'status': self.runner(['systemctl', 'is-system-running'])}
            self.slow_at = now
        frame.update(self.slow)
        if self.details and now - self.processes_at >= 2:
            self.processes = []
            for line in self.runner(['ps', '-eo', 'pcpu,comm', '--sort=-pcpu', '--no-headers']).splitlines()[:3]:
                fields = line.strip().split(None, 1)
                if len(fields) == 2:
                    try:
                        self.processes.append({'cpu': float(fields[0]), 'name': fields[1][:80]})
                    except ValueError:
                        pass
            self.processes_at = now
        frame['processes'] = self.processes if self.details else []
        # Remove baselines of unplugged devices rather than growing forever.
        live = {'net:' + r['id'] for r in frame.get('network') or []}
        live |= {'disk:' + line.split()[0] + ':' + line.split()[1]
                 for line in read(self.proc / 'diskstats').splitlines() if len(line.split()) >= 14}
        self.previous = {k: v for k, v in self.previous.items() if k in live}
        return frame


def main():
    monitor = Monitor()
    monitor.details = "--details" in sys.argv
    while True:
        started = time.monotonic()
        print(json.dumps(monitor.snapshot(started), allow_nan=False), flush=True)
        time.sleep(max(0.05, 1 - (time.monotonic() - started)))


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        pass
