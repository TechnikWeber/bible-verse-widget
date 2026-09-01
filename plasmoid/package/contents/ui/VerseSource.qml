/*
 * Exposes the verse for the current day.
 *
 * The verse lists are compiled into JavaScript library modules by
 * tools/sync_assets.py and imported statically below — Qt 6 refuses
 * XMLHttpRequest on local files, so the data cannot be read at runtime.
 * Everything is local: the widget works offline and needs no network access.
 *
 * Adding a language means adding an import and an entry in `sources`.
 */
import QtQuick
import "selection.js" as Selection
import "verses_de.js" as VersesDe
import "verses_en.js" as VersesEn
import "verses_es.js" as VersesEs

QtObject {
    id: source

    /* "auto", or one of the keys of `sources`. */
    property string language: "auto"

    readonly property var sources: ({
        "de": VersesDe.DATA,
        "en": VersesEn.DATA,
        "es": VersesEs.DATA
    })

    readonly property string resolvedLanguage: {
        if (sources.hasOwnProperty(language)) {
            return language;
        }
        var code = Qt.locale().name.split(/[_\-.]/)[0].toLowerCase();
        return sources.hasOwnProperty(code) ? code : "en";
    }

    /* Local date as YYYY-MM-DD; a change is what selects a new verse. */
    property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")

    property Timer clock: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: source.today = Qt.formatDate(new Date(), "yyyy-MM-dd")
    }

    readonly property var current: {
        var data = sources[resolvedLanguage];
        var verses = data.verses;
        /* `today` is read so that this binding re-evaluates at midnight. */
        var unused = today;
        return verses[Selection.verseIndexForDate(new Date(), verses.length)];
    }

    readonly property string text: current.text
    readonly property string reference: current.ref
    readonly property string translationName: sources[resolvedLanguage].translation.shortName

    /* "<text> — <reference> (<translation>)", for the clipboard. */
    function asPlainText() {
        return text ? text + " — " + reference + " (" + translationName + ")" : "";
    }
}
