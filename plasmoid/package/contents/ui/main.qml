import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    /* A desktop widget: never collapse into an icon. */
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: Plasmoid.configuration.backgroundMode === "panel"
        ? PlasmaCore.Types.DefaultBackground
        : PlasmaCore.Types.NoBackground

    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
    Layout.minimumHeight: Kirigami.Units.gridUnit * 4
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 10

    readonly property bool scaleToWidget: Plasmoid.configuration.fontSizeMode === "fit"
    readonly property bool shadowed: Plasmoid.configuration.backgroundMode === "shadow"
    readonly property color textColor: Plasmoid.configuration.useCustomTextColor
        ? Plasmoid.configuration.textColor
        : Kirigami.Theme.textColor
    readonly property string fontFamily: Plasmoid.configuration.fontFamily
        || Kirigami.Theme.defaultFont.family
    readonly property int horizontalAlignment: Plasmoid.configuration.alignment === "left"
        ? Text.AlignLeft : Text.AlignHCenter

    /* Text.Fit only ever scales *down* from font.pointSize, so "scale to the
     * widget" sets a deliberately generous cap and lets it shrink to fit. */
    readonly property int upperPointSize: 72

    VerseSource {
        id: verse
        mode: Plasmoid.configuration.source
        language: Plasmoid.configuration.language
    }

    toolTipMainText: verse.entries.length > 0 ? verse.entries[0].ref : ""
    toolTipSubText: i18n("%1 — click to copy", verse.attribution)

    fullRepresentation: MouseArea {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 4

        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            var payload = verse.asPlainText();
            if (!payload) {
                return;
            }
            /* Plasma exposes no clipboard type to QML; an off-screen TextEdit
             * is the conventional way to reach QClipboard from a plasmoid. */
            copyHelper.text = payload;
            copyHelper.selectAll();
            copyHelper.copy();
            copyHelper.deselect();
            feedback.flash();
        }

        TextEdit {
            id: copyHelper
            visible: false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: verse.problem ? [] : verse.entries

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: modelData.text
                        color: root.textColor
                        wrapMode: Text.WordWrap
                        horizontalAlignment: root.horizontalAlignment
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight

                        font.family: root.fontFamily
                        font.italic: Plasmoid.configuration.italic
                        font.pointSize: root.scaleToWidget
                            ? root.upperPointSize
                            : Plasmoid.configuration.fontSize
                        fontSizeMode: root.scaleToWidget ? Text.Fit : Text.FixedSize
                        minimumPointSize: 6

                        style: root.shadowed ? Text.Raised : Text.Normal
                        styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        visible: Plasmoid.configuration.showReference

                        text: modelData.ref
                        color: root.textColor
                        opacity: 0.75
                        wrapMode: Text.WordWrap
                        horizontalAlignment: root.horizontalAlignment

                        font.family: root.fontFamily
                        font.bold: true
                        font.pointSize: root.scaleToWidget
                            ? Kirigami.Theme.defaultFont.pointSize
                            : Math.max(6, Plasmoid.configuration.fontSize - 2)

                        style: root.shadowed ? Text.Raised : Text.Normal
                        styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
                    }
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: verse.problem !== ""

                text: verse.problem
                color: root.textColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.fontFamily
            }

            /* The Losungen are used by permission; the notice stays visible. */
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.source === "losungen"
                    && verse.problem === ""

                text: verse.attribution
                color: root.textColor
                opacity: 0.5
                wrapMode: Text.WordWrap
                horizontalAlignment: root.horizontalAlignment
                font.family: root.fontFamily
                font.pointSize: Kirigami.Theme.smallFont.pointSize

                style: root.shadowed ? Text.Raised : Text.Normal
                styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
            }
        }

        PlasmaComponents.Label {
            id: feedback

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: i18n("Copied")
            color: root.textColor
            opacity: 0

            function flash() {
                fade.restart();
            }

            SequentialAnimation {
                id: fade
                NumberAnimation { target: feedback; property: "opacity"; to: 1; duration: 120 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: feedback; property: "opacity"; to: 0; duration: 400 }
            }
        }
    }
}
