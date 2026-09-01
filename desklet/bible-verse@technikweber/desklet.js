/*
 * Bible Verse — a Cinnamon desklet showing one verse per day.
 *
 * The verse lists live in data/*.json and the day-to-verse mapping in
 * selection.js; both are generated from the repository root and shared verbatim
 * with the KDE Plasmoid, so both widgets show the same verse on the same day.
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
        this._dateKey = null;
        this._plainText = "";
        this._timeoutId = 0;

        this.settings = new Settings.DeskletSettings(this, UUID, deskletId);
        const redraw = {
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
        this._verseLabel = new St.Label({ style_class: "bible-verse-text" });
        this._referenceLabel = new St.Label({ style_class: "bible-verse-reference" });

        [this._verseLabel, this._referenceLabel].forEach((label) => {
            const text = label.get_clutter_text();
            text.set_line_wrap(true);
            text.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
            text.set_ellipsize(Pango.EllipsizeMode.NONE);
        });

        this._container = new St.BoxLayout({
            vertical: true,
            reactive: true,
            track_hover: true,
            style_class: "bible-verse-container"
        });
        this._container.add(this._verseLabel, { expand: true, x_fill: true });
        this._container.add(this._referenceLabel, { x_fill: true });
        this._container.connect("button-release-event", () => this._onClicked());

        this.setContent(this._container);
        this._applyStyle();
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

    _refresh: function () {
        const now = new Date();
        this._dateKey = localDateKey(now);

        if (!this._load(this._language())) {
            this._verseLabel.set_text(_("The verses could not be loaded."));
            this._referenceLabel.set_text("");
            this._plainText = "";
            return;
        }

        const verses = this._data.verses;
        const verse = verses[Selection.verseIndexForDate(now, verses.length)];

        this._verseLabel.set_text(verse.text);
        this._referenceLabel.set_text(verse.ref);
        this._referenceLabel.visible = this.show_reference;
        this._plainText = verse.text + " — " + verse.ref +
            " (" + this._data.translation.shortName + ")";
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

        this._verseLabel.set_style(
            family + style + shadow +
            "color: " + this.text_color + "; " +
            "font-size: " + this.font_size + "pt; " +
            "text-align: " + align + ";");

        this._referenceLabel.set_style(
            family + shadow +
            "color: " + this.text_color + "; " +
            "font-size: " + Math.max(6, this.font_size - 2) + "pt; " +
            "font-weight: bold; " +
            "padding-top: 6px; " +
            "text-align: " + align + ";");
    },

    _onSettingsChanged: function () {
        this._refresh();
        this._applyStyle();
    },

    _onClicked: function () {
        if (!this._plainText) {
            return Clutter.EVENT_PROPAGATE;
        }
        St.Clipboard.get_default().set_text(St.ClipboardType.CLIPBOARD, this._plainText);
        return Clutter.EVENT_STOP;
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
