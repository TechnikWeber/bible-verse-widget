/*
 * Bible Verse — a Cinnamon desklet showing one passage per day.
 *
 * Two sources:
 *
 *   "curated"  — the bundled lists in data/*.json, mapped to the day by
 *                selection.js. Both files are generated from the repository
 *                root and shared verbatim with the KDE Plasmoid, so both
 *                widgets show the same verse on the same day.
 *
 *   "losungen" — the Herrnhuter Losungen, imported onto this machine by
 *                tools/import_losungen.py. That data is free for
 *                non-commercial use only, so it is never shipped with the
 *                desklet and is read from the user's data directory instead.
 *                A day then has two passages, the Losung and the Lehrtext.
 *
 * Everything is local — the desklet never touches the network.
 */

const Desklet = imports.ui.desklet;
const DeskletManager = imports.ui.deskletManager;
const Settings = imports.ui.settings;

const Clutter = imports.gi.Clutter;
const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Pango = imports.gi.Pango;
const St = imports.gi.St;

const Gettext = imports.gettext;
const Main = imports.ui.main;
const Mainloop = imports.mainloop;

const UUID = "bible-verse@technikweber";
const DESKLET_DIR = DeskletManager.deskletMeta[UUID].path;

/* Makes selection.js importable as `imports.selection`. */
imports.searchPath.unshift(DESKLET_DIR);
const Selection = imports.selection;

const LANGUAGES = ["de", "en", "es"];
const CHECK_INTERVAL_SECONDS = 60;

Gettext.bindtextdomain(UUID, GLib.get_home_dir() + "/.local/share/locale");

function _(text) {
    return Gettext.dgettext(UUID, text);
}

function decode(bytes) {
    /* TextDecoder since GJS 1.70; imports.byteArray on older Cinnamon. */
    if (typeof TextDecoder !== "undefined") {
        return new TextDecoder().decode(bytes);
    }
    return imports.byteArray.toString(bytes);
}

function systemLanguage() {
    const names = GLib.get_language_names();
    for (let i = 0; i < names.length; i++) {
        const code = names[i].split(/[_\-.@]/)[0].toLowerCase();
        if (LANGUAGES.indexOf(code) >= 0) {
            return code;
        }
    }
    return "en";
}

function localDateKey(date) {
    return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
}

function BibleVerseDesklet(metadata, deskletId) {
    this._init(metadata, deskletId);
}

BibleVerseDesklet.prototype = {
    __proto__: Desklet.Desklet.prototype,

    _init: function (metadata, deskletId) {
        Desklet.Desklet.prototype._init.call(this, metadata, deskletId);

        this._data = null;
        this._loadedLanguage = null;
        this._losungen = null;
        this._losungenYear = 0;
        this._dateKey = null;
        this._plainText = "";
        this._timeoutId = 0;

        this.settings = new Settings.DeskletSettings(this, UUID, deskletId);
        const redraw = {
            "source": "source",
            "losungen-file": "losungen_file",
            "language": "language",
            "show-reference": "show_reference",
            "width": "desklet_width",
            "font-size": "font_size",
            "font-family": "font_family",
            "italic": "italic",
            "centered": "centered",
            "text-color": "text_color",
            "shadow": "shadow"
        };
        for (const key in redraw) {
            this.settings.bind(key, redraw[key], this._onSettingsChanged);
        }

        this._buildUI();
        this._refresh();

        this._timeoutId = Mainloop.timeout_add_seconds(
            CHECK_INTERVAL_SECONDS, () => this._onTick());
    },

    _buildUI: function () {
        this._passages = new St.BoxLayout({ vertical: true });
        this._attributionLabel = this._makeLabel();

        this._container = new St.BoxLayout({
            vertical: true,
            reactive: true,
            track_hover: true,
            style_class: "bible-verse-container"
        });
        this._container.add(this._passages, { expand: true, x_fill: true });
        this._container.add(this._attributionLabel, { x_fill: true });
        this._container.connect("button-release-event", () => this._onClicked());

        this.setContent(this._container);
    },

    _makeLabel: function () {
        const label = new St.Label();
        const text = label.get_clutter_text();
        text.set_line_wrap(true);
        text.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
        text.set_ellipsize(Pango.EllipsizeMode.NONE);
        return label;
    },

    /* One text label plus one reference label per passage. */
    _renderPassages: function (entries) {
        this._passages.destroy_all_children();
        this._textLabels = [];
        this._referenceLabels = [];

        entries.forEach((entry, index) => {
            const text = this._makeLabel();
            text.set_text(entry.text);
            if (index > 0) {
                text.set_style("padding-top: 10px;");
            }
            this._passages.add(text, { x_fill: true });
            this._textLabels.push(text);

            const reference = this._makeLabel();
            reference.set_text(entry.ref);
            reference.visible = this.show_reference;
            this._passages.add(reference, { x_fill: true });
            this._referenceLabels.push(reference);
        });
    },

    /* --- data ------------------------------------------------------------ */

    _language: function () {
        if (LANGUAGES.indexOf(this.language) >= 0) {
            return this.language;
        }
        return systemLanguage();
    },

    _load: function (language) {
        if (this._loadedLanguage === language) {
            return true;
        }
        const path = DESKLET_DIR + "/data/" + language + ".json";
        try {
            const [ok, contents] = Gio.file_new_for_path(path).load_contents(null);
            if (!ok) {
                throw new Error("could not read " + path);
            }
            const parsed = JSON.parse(decode(contents));
            if (!parsed.verses || parsed.verses.length === 0) {
                throw new Error("no verses in " + path);
            }
            this._data = parsed;
            this._loadedLanguage = language;
            return true;
        } catch (error) {
            global.logError("[" + UUID + "] " + error);
            this._data = null;
            this._loadedLanguage = null;
            return false;
        }
    },

    _losungenPath: function (year) {
        return GLib.get_user_data_dir() + "/bible-verse-widget/losungen-" + year + ".json";
    },

    _loadLosungen: function (year) {
        if (this._losungen && this._losungenYear === year) {
            return true;
        }
        const path = this._losungenPath(year);
        const file = Gio.file_new_for_path(path);
        if (!file.query_exists(null)) {
            this._losungen = null;
            return false;
        }
        try {
            const [ok, contents] = file.load_contents(null);
            if (!ok) {
                throw new Error("could not read " + path);
            }
            this._losungen = JSON.parse(decode(contents));
            this._losungenYear = year;
            return true;
        } catch (error) {
            global.logError("[" + UUID + "] " + error);
            this._losungen = null;
            return false;
        }
    },

    _refresh: function () {
        const now = new Date();
        this._dateKey = localDateKey(now);

        const result = this.source === "losungen"
            ? this._losungenFor(now)
            : this._curatedFor(now);

        this._renderPassages(result.entries);
        this._attributionLabel.set_text(result.attribution);
        this._attributionLabel.visible = result.attribution !== "";
        this._plainText = result.entries.length
            ? result.entries.map((e) => e.text + " — " + e.ref).join("\n\n")
              + (result.attribution ? "\n(" + result.attribution + ")" : "")
            : "";
        this._applyStyle();
    },

    _curatedFor: function (now) {
        if (!this._load(this._language())) {
            return { entries: [{ text: _("The verses could not be loaded."), ref: "" }],
                     attribution: "" };
        }
        const verses = this._data.verses;
        const verse = verses[Selection.verseIndexForDate(now, verses.length)];
        return { entries: [{ text: verse.text, ref: verse.ref }], attribution: "" };
    },

    _losungenFor: function (now) {
        const year = now.getFullYear();
        if (!this._loadLosungen(year)) {
            return {
                entries: [{
                    text: _("No Losungen for %s on this machine. Import the year " +
                            "file from losungen.de with tools/import_losungen.py.")
                          .replace("%s", String(year)),
                    ref: ""
                }],
                attribution: ""
            };
        }
        const key = now.getFullYear() + "-"
            + String(now.getMonth() + 1).padStart(2, "0") + "-"
            + String(now.getDate()).padStart(2, "0");
        const day = this._losungen.days.find((d) => d.date === key);
        if (!day) {
            return {
                entries: [{ text: _("No Losung for today in the imported file."), ref: "" }],
                attribution: ""
            };
        }
        return {
            entries: [
                { text: day.losung.text, ref: day.losung.ref },
                { text: day.lehrtext.text, ref: day.lehrtext.ref }
            ],
            /* Used by permission; the notice stays visible. */
            attribution: this._losungen.copyright
        };
    },

    _onTick: function () {
        if (localDateKey(new Date()) !== this._dateKey) {
            this._refresh();
        }
        return true;   /* keep the timeout alive */
    },

    /* --- presentation ---------------------------------------------------- */

    _applyStyle: function () {
        const family = this.font_family ? "font-family: '" + this.font_family + "'; " : "";
        const style = this.italic ? "font-style: italic; " : "";
        const align = this.centered ? "center" : "left";
        const shadow = this.shadow ? "text-shadow: 1px 1px 3px rgba(0,0,0,0.85); " : "";

        this._container.set_style("width: " + this.desklet_width + "px; padding: 8px;");

        (this._textLabels || []).forEach((label, index) => {
            label.set_style(
                family + style + shadow +
                (index > 0 ? "padding-top: 10px; " : "") +
                "color: " + this.text_color + "; " +
                "font-size: " + this.font_size + "pt; " +
                "text-align: " + align + ";");
        });

        (this._referenceLabels || []).forEach((label) => {
            label.set_style(
                family + shadow +
                "color: " + this.text_color + "; " +
                "font-size: " + Math.max(6, this.font_size - 2) + "pt; " +
                "font-weight: bold; " +
                "padding-top: 6px; " +
                "text-align: " + align + ";");
        });

        this._attributionLabel.set_style(
            family + shadow +
            "color: " + this.text_color + "; " +
            "font-size: " + Math.max(6, this.font_size - 5) + "pt; " +
            "padding-top: 8px; " +
            "text-align: " + align + ";");
    },

    _onSettingsChanged: function () {
        this._refresh();   /* re-renders the labels, then re-applies the style */
    },

    _onClicked: function () {
        if (!this._plainText) {
            return Clutter.EVENT_PROPAGATE;
        }
        St.Clipboard.get_default().set_text(St.ClipboardType.CLIPBOARD, this._plainText);
        return Clutter.EVENT_STOP;
    },

    /* Settings button: runs the importer that ships inside this desklet. */
    onImportLosungen: function () {
        const file = (this.losungen_file || "").replace(/^file:\/\//, "");
        if (!file) {
            this._notifyImport(_("Select the downloaded Losungen file first."));
            return;
        }
        const script = DESKLET_DIR + "/import_losungen.py";
        try {
            const [ok, out, err, status] = GLib.spawn_sync(
                null, ["python3", script, decodeURIComponent(file)], null,
                GLib.SpawnFlags.SEARCH_PATH, null);
            const message = decode(err).trim() || decode(out).trim();
            if (!ok || status !== 0) {
                throw new Error(message || "exit status " + status);
            }
            this._losungen = null;      /* force a re-read */
            this._losungenYear = 0;
            this._refresh();
            this._notifyImport(message.split("\n")[0].trim());
        } catch (error) {
            global.logError("[" + UUID + "] " + error);
            this._notifyImport(_("Import failed: ") + error.message);
        }
    },

    _notifyImport: function (text) {
        Main.notify(_("Bible Verse"), text);
    },

    on_desklet_removed: function () {
        if (this._timeoutId) {
            Mainloop.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
        this.settings.finalize();
    }
};

function main(metadata, deskletId) {
    return new BibleVerseDesklet(metadata, deskletId);
}
