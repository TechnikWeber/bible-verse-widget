import QtCore
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: page

    property string cfg_source
    property string cfg_language
    property bool cfg_showReference
    property string cfg_fontSizeMode
    property int cfg_fontSize
    property string cfg_fontFamily
    property bool cfg_italic
    property bool cfg_useCustomTextColor
    property color cfg_textColor
    property string cfg_backgroundMode
    property string cfg_alignment

    Kirigami.FormLayout {
        anchors.fill: parent

        Controls.ComboBox {
            id: sourceBox
            Kirigami.FormData.label: i18n("Source:")
            readonly property var options: [
                { value: "curated",  label: i18n("Curated verse list (offline)") },
                { value: "losungen", label: i18n("Herrnhuter Losungen") }
            ]
            model: options
            textRole: "label"
            valueRole: "value"
            /* indexOfValue() reads the model from C++, so a binding on it is
             * never re-evaluated once the model exists. Plasma can supply the
             * config value before that, which left the box showing the first
             * entry while the setting itself was something else. Matching
             * against a declared property keeps the binding honest. */
            currentIndex: {
                for (var index = 0; index < options.length; index++) {
                    if (options[index].value === cfg_source) {
                        return index;
                    }
                }
                return 0;
            }
            onActivated: cfg_source = currentValue
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Losungen file:")
            visible: cfg_source === "losungen"
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                text: i18n("The Losungen are free for non-commercial use only, so "
                         + "they are not shipped with this widget. Download the year "
                         + "file from losungen.de, then import it here. Repeat once "
                         + "a year.")
            }

            RowLayout {
                Controls.Button {
                    icon.name: "document-import"
                    text: i18n("Import year file…")
                    enabled: !importer.running
                    onClicked: fileDialog.open()
                }

                Controls.Button {
                    icon.name: "internet-web-browser"
                    text: i18n("Open losungen.de")
                    onClicked: Qt.openUrlExternally("https://www.losungen.de/digital/")
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: text !== ""
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                color: importer.failed ? Kirigami.Theme.negativeTextColor
                                       : Kirigami.Theme.positiveTextColor
                text: importer.message
            }
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Translation:")
            enabled: cfg_source === "curated"
            readonly property var options: [
                { value: "auto", label: i18n("Follow system language") },
                { value: "de",   label: i18n("German — Lutherbibel 1912") },
                { value: "en",   label: i18n("English — World English Bible") },
                { value: "es",   label: i18n("Spanish — Reina-Valera 1909") }
            ]
            model: options
            textRole: "label"
            valueRole: "value"
            currentIndex: {
                for (var index = 0; index < options.length; index++) {
                    if (options[index].value === cfg_language) {
                        return index;
                    }
                }
                return 0;
            }
            onActivated: cfg_language = currentValue
        }

        Controls.CheckBox {
            Kirigami.FormData.label: i18n("Reference:")
            text: i18n("Show book, chapter and verse")
            checked: cfg_showReference
            onToggled: cfg_showReference = checked
        }

        Item { Kirigami.FormData.isSection: true }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Text size:")
            readonly property var options: [
                { value: "fit",   label: i18n("Scale to the widget") },
                { value: "fixed", label: i18n("Fixed size") }
            ]
            model: options
            textRole: "label"
            valueRole: "value"
            currentIndex: {
                for (var index = 0; index < options.length; index++) {
                    if (options[index].value === cfg_fontSizeMode) {
                        return index;
                    }
                }
                return 0;
            }
            onActivated: cfg_fontSizeMode = currentValue
        }

        Controls.SpinBox {
            Kirigami.FormData.label: i18n("Point size:")
            enabled: cfg_fontSizeMode === "fixed"
            from: 6
            to: 96
            value: cfg_fontSize
            onValueModified: cfg_fontSize = value
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Font:")

            Controls.ComboBox {
                Layout.fillWidth: true
                readonly property var families: [""].concat(Qt.fontFamilies())
                model: families
                displayText: currentIndex === 0 ? i18n("Desktop default") : currentText
                currentIndex: Math.max(0, families.indexOf(cfg_fontFamily))
                onActivated: cfg_fontFamily = currentIndex === 0 ? "" : currentText
            }

            Controls.CheckBox {
                text: i18n("Italic")
                checked: cfg_italic
                onToggled: cfg_italic = checked
            }
        }

        Item { Kirigami.FormData.isSection: true }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Alignment:")
            readonly property var options: [
                { value: "center", label: i18n("Centred") },
                { value: "left",   label: i18n("Left") }
            ]
            model: options
            textRole: "label"
            valueRole: "value"
            currentIndex: {
                for (var index = 0; index < options.length; index++) {
                    if (options[index].value === cfg_alignment) {
                        return index;
                    }
                }
                return 0;
            }
            onActivated: cfg_alignment = currentValue
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Background:")
            readonly property var options: [
                { value: "panel",  label: i18n("Plasma panel background") },
                { value: "shadow", label: i18n("None, with a shadow behind the text") },
                { value: "none",   label: i18n("None") }
            ]
            model: options
            textRole: "label"
            valueRole: "value"
            currentIndex: {
                for (var index = 0; index < options.length; index++) {
                    if (options[index].value === cfg_backgroundMode) {
                        return index;
                    }
                }
                return 0;
            }
            onActivated: cfg_backgroundMode = currentValue
        }

        Item { Kirigami.FormData.isSection: true }

        ColumnLayout {
            Kirigami.FormData.label: i18n("After an update:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                text: i18n("Plasma keeps running widgets on the code they started "
                         + "with, so a newly installed version only appears after "
                         + "the desktop shell restarts. Panels and the desktop "
                         + "blink; windows and applications are not affected.")
            }

            Controls.Button {
                icon.name: "system-reboot"
                text: i18n("Restart Plasma now")
                onClicked: shellRestarter.restart()
            }
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Text colour:")

            Controls.CheckBox {
                text: i18n("Custom")
                checked: cfg_useCustomTextColor
                onToggled: cfg_useCustomTextColor = checked
            }

            Controls.Button {
                enabled: cfg_useCustomTextColor
                onClicked: colourDialog.open()

                contentItem: Rectangle {
                    implicitWidth: Kirigami.Units.gridUnit * 3
                    implicitHeight: Kirigami.Units.gridUnit
                    color: cfg_textColor
                    border.color: Kirigami.Theme.textColor
                    border.width: 1
                    radius: 2
                }
            }
        }
    }

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Select the Losungen year file")
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        nameFilters: [
            i18n("Losungen file (*.zip *.xml)"),
            i18n("All files (*)")
        ]
        onAccepted: importer.run(selectedFile)
    }

    /* Runs the importer that ships inside this package. A plasmoid has no other
     * way to touch the file system, and the importer is a plain script so that
     * it can also be used from a terminal. */
    P5Support.DataSource {
        id: importer

        property bool running: false
        property bool failed: false
        property string message: ""

        engine: "executable"
        connectedSources: []

        function run(fileUrl) {
            var path = fileUrl.toString().replace(/^file:\/\//, "");
            var script = Qt.resolvedUrl("../code/import_losungen.py")
                .toString().replace(/^file:\/\//, "");
            running = true;
            failed = false;
            message = i18n("Importing…");
            connectSource('python3 "' + script + '" "' + decodeURIComponent(path) + '"');
        }

        onNewData: function (name, data) {
            disconnectSource(name);
            running = false;
            failed = data["exit code"] !== 0;
            var output = (data["stderr"] || data["stdout"] || "").trim();
            message = failed
                ? i18n("Import failed: %1", output.split("\n").pop())
                : i18n("Imported. %1", output.split("\n")[0].trim());
        }
    }

    /* Restarting the shell kills this dialog and the process that launched the
     * command, so the command is detached with setsid first. systemd owns
     * plasmashell on a normal Plasma 6 session; the kquitapp fallback covers a
     * session started some other way. */
    P5Support.DataSource {
        id: shellRestarter

        engine: "executable"
        connectedSources: []

        function restart() {
            connectSource(
                "setsid --fork sh -c '"
                + "systemctl --user restart plasma-plasmashell.service "
                + "|| { kquitapp6 plasmashell; sleep 2; kstart plasmashell; }"
                + "' >/dev/null 2>&1");
        }

        onNewData: function (name) {
            disconnectSource(name);
        }
    }

    Dialogs.ColorDialog {
        id: colourDialog
        title: i18n("Text colour")
        selectedColor: cfg_textColor
        onAccepted: cfg_textColor = selectedColor
    }
}
