import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

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
            Kirigami.FormData.label: i18n("Translation:")
            model: [
                { value: "auto", label: i18n("Follow system language") },
                { value: "de",   label: i18n("German — Lutherbibel 1912") },
                { value: "en",   label: i18n("English — World English Bible") },
                { value: "es",   label: i18n("Spanish — Reina-Valera 1909") }
            ]
            textRole: "label"
            valueRole: "value"
            onActivated: cfg_language = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_language)
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
            model: [
                { value: "fit",   label: i18n("Scale to the widget") },
                { value: "fixed", label: i18n("Fixed size") }
            ]
            textRole: "label"
            valueRole: "value"
            onActivated: cfg_fontSizeMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_fontSizeMode)
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
                model: [""].concat(Qt.fontFamilies())
                displayText: currentIndex === 0 ? i18n("Desktop default") : currentText
                onActivated: cfg_fontFamily = currentIndex === 0 ? "" : currentText
                Component.onCompleted: {
                    var index = model.indexOf(cfg_fontFamily);
                    currentIndex = index > 0 ? index : 0;
                }
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
            model: [
                { value: "center", label: i18n("Centred") },
                { value: "left",   label: i18n("Left") }
            ]
            textRole: "label"
            valueRole: "value"
            onActivated: cfg_alignment = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_alignment)
        }

        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Background:")
            model: [
                { value: "panel",  label: i18n("Plasma panel background") },
                { value: "shadow", label: i18n("None, with a shadow behind the text") },
                { value: "none",   label: i18n("None") }
            ]
            textRole: "label"
            valueRole: "value"
            onActivated: cfg_backgroundMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_backgroundMode)
        }

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

    Dialogs.ColorDialog {
        id: colourDialog
        title: i18n("Text colour")
        selectedColor: cfg_textColor
        onAccepted: cfg_textColor = selectedColor
    }
}
