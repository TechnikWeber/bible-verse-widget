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

        FittedContent {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing

            entries: verse.problem ? [] : verse.entries
            /* The Losungen are used by permission; the notice stays visible. */
            attribution: Plasmoid.configuration.source === "losungen" && !verse.problem
                ? verse.attribution : ""
            showReference: Plasmoid.configuration.showReference

            autoFit: root.scaleToWidget
            fixedPointSize: Plasmoid.configuration.fontSize

            fontFamily: root.fontFamily
            italic: Plasmoid.configuration.italic
            textColor: root.textColor
            horizontalAlignment: root.horizontalAlignment
            shadowed: root.shadowed
        }

        PlasmaComponents.Label {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            visible: verse.problem !== ""

            text: verse.problem
            color: root.textColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: root.fontFamily
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
