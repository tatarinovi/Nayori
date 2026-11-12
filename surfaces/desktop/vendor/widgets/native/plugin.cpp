// Nayori adapter: register the original Ryoku painter in a local QML directory.
// GPL-3.0; upstream cavaspectrum.{cpp,hpp} are unchanged.
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include "cavaspectrum.hpp"

class NayoriWidgetsPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        qmlRegisterType<CavaSpectrumPainter>(uri, 1, 0, "CavaSpectrumPainter");
    }
};

#include "plugin.moc"
