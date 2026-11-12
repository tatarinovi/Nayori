# Original spectrum painter

`cavaspectrum.cpp` and `cavaspectrum.hpp` are unchanged sources from Ryoku
`2befae30e0e1e8d370a8fdb4489e84be529af1bd`,
`ryoku/shell/plugin/cavaspectrum.{cpp,hpp}`:
https://github.com/Ryoku-dev/ryoku/tree/2befae30e0e1e8d370a8fdb4489e84be529af1bd/ryoku/shell/plugin

They retain Ryoku's GNU GPL v3 license and author notices. The full license and
upstream NOTICE are supplied in the parent vendor directory and Nayori LICENSE.
Original and adapted SHA-256 values are recorded in `../manifest.json`.
The separate Shima iNiR notice remains in `../shima-NOTICE`.

`plugin.cpp`, `qmldir` and `scripts/build-widget-renderer.py` are Nayori's GPL-3.0
host adapter (2026). The adapter registers the original class as a directory QML
plugin. It does not replace the painter or start an audio collector. QML gets its
points from Nayori's existing AudioReaction. Qt documents local plugin discovery:
https://doc.qt.io/qt-6/qtqml-syntax-directoryimports.html

Build from the repository root:

```sh
python3 scripts/build-widget-renderer.py
```

Requires Linux, C++20, pkg-config, Qt 6 Quick development headers, moc and
qmltyperegistrar. The script produces `libnayori_widgets_plugin.so` and its tooling
description `plugins.qmltypes`; it neither loads QML nor runs tests. Rebuild after
changing Qt ABI. Do not commit the host-specific shared object. CI builds before
checks; the installer builds inside the unpublished release before hashing it.
