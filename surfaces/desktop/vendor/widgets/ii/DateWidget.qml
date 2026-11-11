import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts






import Qt5Compat.GraphicalEffects

AbstractBackgroundWidget {
    readonly property var nayoriDateWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "date"

    implicitWidth: 240
    implicitHeight: 240

    readonly property color expressiveMonthRect: nayoriDateWidget.colors.innerShapeColor
    readonly property color expressiveDayNumber: nayoriDateWidget.colors.accentColor

    StyledRectangularShadow {
        id: bgShadow
        target: bgRect
        visible: nayoriDateWidget.config.options.background.widgets.enableShadows ?? true
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: nayoriDateWidget.colors.tintBackground(nayoriDateWidget.colors.cardBgColor)
        radius: nayoriDateWidget.appearance.rounding.windowRounding

        // Recorte da camada ativado apenas se a sombra interna estiver ligada
        layer.enabled: nayoriDateWidget.config.options.background.widgets.enableInnerShadow ?? true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bgRect.width
                height: bgRect.height
                radius: bgRect.radius
                antialiasing: true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0

            Rectangle {
                id: monthRect
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: nayoriDateWidget.colors.tintBackground(root.expressive ? root.expressiveMonthRect : nayoriDateWidget.colors.innerShapeColor)
                radius: nayoriDateWidget.appearance.rounding.normal

                StyledText {
                    anchors.centerIn: parent
                    text: {
                        let monthStr = Qt.locale().toString(nayoriDateWidget.dateTime.clock.date, "MMM").replace(".", "").substring(0, 3);
                        return (nayoriDateWidget.config.options.background.widgets.date.uppercaseMonth ?? true)
                            ? monthStr.toUpperCase() : monthStr;
                    }
                    font {
                        pixelSize: 42
                        bold: true
                        family: nayoriDateWidget.appearance.font.family.main
                    }
                    color: root.expressive ? nayoriDateWidget.colors.onAccentColor : nayoriDateWidget.colors.subtextColorOnBg
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    text: nayoriDateWidget.dateTime.clock.date.getDate().toString()
                    font {
                        pixelSize: 98
                        weight: Font.Black
                        bold: true
                        family: "Google Sans Flex"
                        variableAxes: ({ "ROND": 100, "wght": 800 })
                    }
                    color: root.expressive ? root.expressiveDayNumber : nayoriDateWidget.colors.textColorOnBg
                }
            }
        }

        // Moldura do Canvas com recorte (furo) para projetar a sombra para dentro
        Canvas {
            id: shadowMaskCanvas
            x: -80
            y: -80
            width: bgRect.width + 160
            height: bgRect.height + 160
            visible: false

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "black";
                ctx.beginPath();
                ctx.rect(0, 0, width, height);

                var rx = 80;
                var ry = 80;
                var rw = bgRect.width;
                var rh = bgRect.height;
                // Reduzimos o raio do cutout na moldura para compensar a sobreposição da sombra nos cantos
                var r = Math.max(0, bgRect.radius - 8);

                ctx.moveTo(rx + r, ry);
                ctx.arcTo(rx, ry, rx, ry + r, r);
                ctx.lineTo(rx, ry + rh - r);
                ctx.arcTo(rx, ry + rh, rx + r, ry + rh, r);
                ctx.lineTo(rx + rw - r, ry + rh);
                ctx.arcTo(rx + rw, ry + rh, rx + rw, ry + rh - r, r);
                ctx.lineTo(rx + rw, ry + r);
                ctx.arcTo(rx + rw, ry, rx + rw - r, ry, r);
                ctx.lineTo(rx + r, ry);

                ctx.closePath();
                ctx.fill("evenodd");
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        DropShadow {
            id: innerShadow
            x: -80
            y: -80
            width: shadowMaskCanvas.width
            height: shadowMaskCanvas.height
            source: shadowMaskCanvas
            radius: 24 // Soft blur equilibrado para o tamanho do widget
            samples: 49
            color: Qt.rgba(0, 0, 0, 0.35)
            horizontalOffset: 0
            verticalOffset: 0
            visible: nayoriDateWidget.config.options.background.widgets.enableInnerShadow ?? true
        }
    }
}
