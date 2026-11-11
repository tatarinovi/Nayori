import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects



Item {
    readonly property var nayoriMusicFaceLyricsSimple: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 180
    property real minHeight: 60
    property real maxWidth: 2400
    property real maxHeight: 1200
    property real minAspect: 0.5
    property real maxAspect: 8.0
    property bool isRound: false

    property bool lyricsSubscribed: false

    property int lyricsLines: 1
    property string lyricsAlignment: "left"
    property bool showNoLyrics: true

    function getThemePrimaryColor() {
        if (!!nayoriMusicFaceLyricsSimple.pythonTheme) {
            if (nayoriMusicFaceLyricsSimple.pythonTheme.primary) return Qt.color(nayoriMusicFaceLyricsSimple.pythonTheme.primary);
            if (nayoriMusicFaceLyricsSimple.pythonTheme.blue) return Qt.color(nayoriMusicFaceLyricsSimple.pythonTheme.blue);
            if (nayoriMusicFaceLyricsSimple.pythonTheme.mauve) return Qt.color(nayoriMusicFaceLyricsSimple.pythonTheme.mauve);
        }
        return Qt.color("#89b4fa");
    }

    function syncSubscription() {
        if (root.visible && !root.lyricsSubscribed) {
            root.lyricsSubscribed = true;
            nayoriMusicFaceLyricsSimple.lyrics.subscribe();
        } else if (!root.visible && root.lyricsSubscribed) {
            root.lyricsSubscribed = false;
            nayoriMusicFaceLyricsSimple.lyrics.unsubscribe();
        }
    }

    readonly property color primaryColor: getThemePrimaryColor()
    readonly property color activeLineColor: root.primaryColor

    readonly property real sideMargin: Math.max(nayoriMusicFaceLyricsSimple.scaler.s(12), root.width * 0.05)
    readonly property real refWidth: nayoriMusicFaceLyricsSimple.scaler.s(320)
    readonly property real refHeight: nayoriMusicFaceLyricsSimple.scaler.s(100)
    readonly property real effectiveSize: Math.sqrt((root.width / Math.max(1, refWidth)) * (root.height / Math.max(1, refHeight)))
    readonly property real fontScale: Math.pow(Math.max(0.3, effectiveSize), 0.38)

    readonly property real baseActiveFont: Math.max(nayoriMusicFaceLyricsSimple.scaler.s(11), Math.min(root.height * 0.24, nayoriMusicFaceLyricsSimple.scaler.s(15) * fontScale))

    onVisibleChanged: syncSubscription()

    Component.onCompleted: {
        syncSubscription();
    }

    Component.onDestruction: {
        if (root.lyricsSubscribed) {
            root.lyricsSubscribed = false;
            nayoriMusicFaceLyricsSimple.lyrics.unsubscribe();
        }
    }

    LyricsView {
        id: lyricsViewport
        anchors.fill: parent
        alignment: root.lyricsAlignment
        visible: opacity > 0.0
        opacity: (nayoriMusicFaceLyricsSimple.lyrics.isMediaActive && nayoriMusicFaceLyricsSimple.lyrics.hasLyrics) ? 1.0 : 0.0
        linesBehind: Math.max(0, Math.min(4, Math.round(root.lyricsLines)))
        linesAfter: Math.max(0, Math.min(4, Math.round(root.lyricsLines)))
        sideMargin: root.sideMargin
        baseActiveFont: root.baseActiveFont
        lineHeight: Math.max(nayoriMusicFaceLyricsSimple.scaler.s(18), root.baseActiveFont * 1.4)
        lineSpacing: Math.max(nayoriMusicFaceLyricsSimple.scaler.s(2), root.baseActiveFont * 0.25)
        activeLineColor: root.activeLineColor
        inactiveLineColor: "#ffffff"
        inactiveOpacity: 0.70
        fontFamily: (!!nayoriMusicFaceLyricsSimple.pythonTheme && nayoriMusicFaceLyricsSimple.pythonTheme.fontFamily) ? nayoriMusicFaceLyricsSimple.pythonTheme.fontFamily : "sans-serif"

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: nayoriMusicFaceLyricsSimple.scaler.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }

        Behavior on opacity {
            NumberAnimation {
                duration: (nayoriMusicFaceLyricsSimple.reducedMotion ? 0 : 250)
                easing.type: Easing.OutQuad
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !(nayoriMusicFaceLyricsSimple.lyrics.isMediaActive && nayoriMusicFaceLyricsSimple.lyrics.hasLyrics) && (root.showNoLyrics || !nayoriMusicFaceLyricsSimple.lyrics.isMediaActive || nayoriMusicFaceLyricsSimple.lyrics.loading)
        text: {
            if (!!nayoriMusicFaceLyricsSimple.i18n) {
                if (!nayoriMusicFaceLyricsSimple.lyrics.isMediaActive) return nayoriMusicFaceLyricsSimple.i18n.t("music.nothing_playing");
                if (nayoriMusicFaceLyricsSimple.lyrics.loading) return nayoriMusicFaceLyricsSimple.i18n.t("music.searching_lyrics");
                return nayoriMusicFaceLyricsSimple.i18n.t("music.no_lyrics");
            }
            if (!nayoriMusicFaceLyricsSimple.lyrics.isMediaActive) return "Nothing is playing";
            if (nayoriMusicFaceLyricsSimple.lyrics.loading) return "Searching lyrics...";
            return "No lyrics available";
        }
        font.family: (!!nayoriMusicFaceLyricsSimple.pythonTheme && nayoriMusicFaceLyricsSimple.pythonTheme.fontFamily) ? nayoriMusicFaceLyricsSimple.pythonTheme.fontFamily : "sans-serif"
        font.weight: Font.DemiBold
        font.pixelSize: nayoriMusicFaceLyricsSimple.scaler.s(12)
        color: (!!nayoriMusicFaceLyricsSimple.pythonTheme && nayoriMusicFaceLyricsSimple.pythonTheme.subtext0) ? nayoriMusicFaceLyricsSimple.pythonTheme.subtext0 : "#a6adc8"

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: nayoriMusicFaceLyricsSimple.scaler.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }
    }
}
