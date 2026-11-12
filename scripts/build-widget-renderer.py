"""Build the original spectrum painter locally; does not load QML or run tests."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'surfaces/desktop/vendor/widgets/native'


def build(destination):
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    compiler = shutil.which(os.environ.get('CXX', 'c++'))
    pkgconfig = shutil.which('pkg-config')
    if not compiler or not pkgconfig:
        raise RuntimeError('C++ compiler and pkg-config are required to build the spectrum painter')
    flags = shlex.split(subprocess.check_output([pkgconfig, '--cflags', '--libs', 'Qt6Quick'], text=True))
    host = subprocess.check_output([pkgconfig, '--variable=libexecdir', 'Qt6Core'], text=True).strip()
    moc = next((path for path in (Path(host) / 'moc', Path('/usr/lib/qt6/moc'), Path('/usr/lib/qt6/bin/moc')) if path.is_file()), None)
    if not moc:
        raise RuntimeError('Qt 6 moc is required to build the spectrum painter')
    includes = [flag for flag in flags if flag.startswith(('-I', '-D', '-F', '-U'))]
    with tempfile.TemporaryDirectory(prefix='nayori-spectrum-build-') as temporary:
        output = Path(temporary)
        subprocess.run([str(moc), '--output-json', *includes, str(SOURCE / 'cavaspectrum.hpp'), '-o', str(output / 'moc_cavaspectrum.cpp')], check=True)
        subprocess.run([str(moc), *includes, str(SOURCE / 'plugin.cpp'), '-o', str(output / 'plugin.moc')], check=True)
        library = output / 'libnayori_widgets_plugin.so'
        subprocess.run([compiler, '-std=c++20', '-shared', '-fPIC', '-O2', '-I' + str(SOURCE), '-I' + str(output),
                        str(SOURCE / 'plugin.cpp'), str(SOURCE / 'cavaspectrum.cpp'), str(output / 'moc_cavaspectrum.cpp'),
                        '-o', str(library), *flags], check=True)
        # Atomic publication never truncates a module mapped by an existing shell.
        staging = destination / '.libnayori_widgets_plugin.so.new'
        shutil.copyfile(library, staging)
        os.replace(staging, destination / library.name)
        registrar = Path(host) / 'qmltyperegistrar'
        if not registrar.is_file():
            raise RuntimeError('Qt 6 qmltyperegistrar is required to describe the spectrum painter')
        subprocess.run([str(registrar), '--import-name=native', '--major-version=1', '--minor-version=0',
                        '--generate-qmltypes=' + str(output / 'plugins.qmltypes'), '-o', str(output / 'registration.cpp'),
                        str(output / 'moc_cavaspectrum.cpp.json')], check=True)
        shutil.copyfile(output / 'plugins.qmltypes', destination / 'plugins.qmltypes')
    if destination != SOURCE:
        shutil.copyfile(SOURCE / 'qmldir', destination / 'qmldir')
    print('Built spectrum painter: ' + str(destination / 'libnayori_widgets_plugin.so'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=SOURCE)
    build(parser.parse_args().output)
