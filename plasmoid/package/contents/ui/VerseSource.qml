/*
 * Exposes the passages for the current day, from one of two sources.
 *
 * "curated"  — the bundled list. The verse lists are compiled into JavaScript
 *              library modules by tools/sync_assets.py and imported statically
 *              below, because Qt 6 refuses XMLHttpRequest on local files. Fully
 *              offline.
 *
 * "losungen" — the Herrnhuter Losungen, imported onto this machine by
 *              tools/import_losungen.py. That data is free for non-commercial
 *              use only and is therefore never shipped with the program, so it
 *              has to be read at runtime. Plasma's executable data engine is
 *              the only way a plasmoid can read a file it did not ship with.
 *
 * Adding a language to the curated source means adding an import and an entry
 * in `translations`.
 */
import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "selection.js" as Selection
import "verses_de.js" as VersesDe
import "verses_en.js" as VersesEn
import "verses_es.js" as VersesEs

QtObject {
    id: source

    /* "curated" or "losungen". */
    property string mode: "curated"
    /* "auto", or one of the keys of `translations`. Curated source only. */
    property string language: "auto"

    readonly property var translations: ({
        "de": VersesDe.DATA,
        "en": VersesEn.DATA,
        "es": VersesEs.DATA
    })

    /* [{ text, ref }] — one entry for a curated verse, two for a Losung and
     * its Lehrtext. */
    readonly property var entries: mode === "losungen" ? losungenEntries : curatedEntries
    readonly property string attribution: mode === "losungen"
        ? losungenAttribution
        : translations[resolvedLanguage].translation.shortName
    readonly property string problem: mode === "losungen" ? losungenProblem : ""

    /* Local date; a change is what selects a new passage. */
    property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")

    property Timer clock: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: source.today = Qt.formatDate(new Date(), "yyyy-MM-dd")
    }

    /* --- curated ------------------------------------------------------- */

    readonly property string resolvedLanguage: {
        if (translations.hasOwnProperty(language)) {
            return language;
        }
        var code = Qt.locale().name.split(/[_\-.]/)[0].toLowerCase();
        return translations.hasOwnProperty(code) ? code : "en";
    }

    readonly property var curatedEntries: {
        var verses = translations[resolvedLanguage].verses;
        var unused = today;   /* read so this re-evaluates at midnight */
        var verse = verses[Selection.verseIndexForDate(new Date(), verses.length)];
        return [{ "text": verse.text, "ref": verse.ref }];
    }

    /* --- Herrnhuter Losungen -------------------------------------------- */

    property var losungenData: null
    property string losungenAttribution: ""
    property string losungenProblem: ""

    readonly property var losungenEntries: {
        var unused = today;
        if (!losungenData) {
            return [];
        }
        var days = losungenData.days;
        for (var i = 0; i < days.length; i++) {
            if (days[i].date === today) {
                return [
                    { "text": days[i].losung.text, "ref": days[i].losung.ref },
                    { "text": days[i].lehrtext.text, "ref": days[i].lehrtext.ref }
                ];
            }
        }
        return [];
    }

    property var reader: P5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: function (name, data) {
            disconnectSource(name);
            source.applyLosungen(data["exit code"] === 0 ? data["stdout"] : "");
        }
    }

    onModeChanged: loadLosungen()
    onTodayChanged: {
        if (mode === "losungen"
                && (!losungenData || losungenData.year !== parseInt(today.substring(0, 4)))) {
            loadLosungen();
        }
    }
    Component.onCompleted: loadLosungen()

    function loadLosungen() {
        if (mode !== "losungen") {
            return;
        }
        losungenProblem = "";
        /* The XDG data directory is resolved by the shell rather than through
         * QtCore.StandardPaths, so that XDG_DATA_HOME is honoured. The only
         * interpolated value is the four-digit year. */
        reader.connectSource(
            'cat "${XDG_DATA_HOME:-$HOME/.local/share}/bible-verse-widget/losungen-'
            + today.substring(0, 4) + '.json" 2>/dev/null');
    }

    function applyLosungen(payload) {
        if (!payload) {
            losungenData = null;
            losungenProblem = i18n("No Losungen for %1 on this machine. Import the "
                                  + "year file from losungen.de with "
                                  + "tools/import_losungen.py.", today.substring(0, 4));
            return;
        }
        try {
            var parsed = JSON.parse(payload);
            losungenData = parsed;
            losungenAttribution = parsed.copyright;
            losungenProblem = "";
        } catch (error) {
            losungenData = null;
            losungenProblem = i18n("The Losungen file could not be read.");
        }
    }

    /* --- clipboard ------------------------------------------------------ */

    function asPlainText() {
        var parts = [];
        for (var i = 0; i < entries.length; i++) {
            parts.push(entries[i].text + " — " + entries[i].ref);
        }
        if (parts.length === 0) {
            return "";
        }
        return parts.join("\n\n") + "\n(" + attribution + ")";
    }
}
