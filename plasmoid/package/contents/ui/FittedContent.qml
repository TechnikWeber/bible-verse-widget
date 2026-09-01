/*
 * Lays out the passages of a day and, in "scale to the widget" mode, picks the
 * largest font size at which all of them fit.
 *
 * Text.Fit is not enough here for two reasons. It sizes every label on its own,
 * so a Losung and its Lehrtext ended up at visibly different sizes in the same
 * widget; and it stops shrinking at minimumPointSize and elides after that, so
 * the text was cut off anyway. Instead one point size drives the whole block
 * and is searched for explicitly.
 *
 * The search measures the Text items directly rather than the enclosing Column.
 * A Text updates its implicit size synchronously when its font changes, while a
 * positioner only does so on the next polish — which would make every
 * measurement one step stale.
 */
import QtQuick

Item {
    id: root

    clip: true

    /* [{ text, ref }] */
    property var entries: []
    property string attribution: ""
    property bool showReference: true

    /* false keeps `fixedPointSize` and lets overflowing text elide. */
    property bool autoFit: true
    property int fixedPointSize: 16

    property string fontFamily: ""
    property bool italic: false
    property color textColor: "white"
    property int horizontalAlignment: Text.AlignHCenter
    property bool shadowed: false

    readonly property int minimumPointSize: 6
    readonly property int maximumPointSize: 96

    property int pointSize: fixedPointSize
    /* Cleared by applyCaps() when there is no room left for the notice. */
    property bool attributionFits: true

    readonly property int referencePointSize:
        Math.max(minimumPointSize, Math.round(pointSize * 0.62))
    readonly property int attributionPointSize:
        Math.max(minimumPointSize, Math.round(pointSize * 0.52))
    readonly property real blockSpacing: Math.round(pointSize * 1.1)
    readonly property real referenceSpacing: Math.round(pointSize * 0.35)

    Column {
        id: column

        width: parent.width
        /* Centred while it fits, top-aligned once it does not — otherwise an
         * overflow would be cut off at the top as well as the bottom. */
        y: Math.max(0, (root.height - height) / 2)
        spacing: root.blockSpacing

        Repeater {
            id: repeater
            model: root.entries

            Item {
                id: block

                required property var modelData

                width: column.width
                height: passage.height + referenceHeight

                /* -1: as tall as the text needs. A positive value caps the
                 * passage so it elides instead of running past the widget. */
                property real textCap: -1

                readonly property real referenceHeight: referenceLabel.visible
                    ? root.referenceSpacing + referenceLabel.implicitHeight
                    : 0
                readonly property real fullHeight: passage.implicitHeight + referenceHeight

                Text {
                    id: passage

                    width: parent.width
                    height: block.textCap >= 0
                        ? Math.min(implicitHeight, block.textCap)
                        : implicitHeight

                    text: block.modelData.text
                    color: root.textColor
                    wrapMode: Text.Wrap
                    horizontalAlignment: root.horizontalAlignment
                    elide: block.textCap >= 0 ? Text.ElideRight : Text.ElideNone

                    font.family: root.fontFamily
                    font.italic: root.italic
                    font.pointSize: root.pointSize

                    style: root.shadowed ? Text.Raised : Text.Normal
                    styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
                }

                Text {
                    id: referenceLabel

                    y: passage.height + root.referenceSpacing
                    width: parent.width
                    visible: root.showReference && block.modelData.ref !== ""

                    text: block.modelData.ref
                    color: root.textColor
                    opacity: 0.75
                    wrapMode: Text.Wrap
                    horizontalAlignment: root.horizontalAlignment

                    font.family: root.fontFamily
                    font.bold: true
                    font.pointSize: root.referencePointSize

                    style: root.shadowed ? Text.Raised : Text.Normal
                    styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
                }
            }
        }

        Text {
            id: attributionLabel

            width: column.width
            visible: root.attribution !== "" && root.attributionFits

            text: root.attribution
            color: root.textColor
            opacity: 0.5
            wrapMode: Text.Wrap
            horizontalAlignment: root.horizontalAlignment

            font.family: root.fontFamily
            font.pointSize: root.attributionPointSize

            style: root.shadowed ? Text.Raised : Text.Normal
            styleColor: root.shadowed ? Qt.rgba(0, 0, 0, 0.7) : "transparent"
        }
    }

    /* --- fitting -------------------------------------------------------- */

    /* Height the content wants at the current point size, laid out the way the
     * Column will lay it out. Returns -1 while the delegates are still being
     * created. */
    function wantedHeight() {
        var total = 0;
        var items = 0;
        for (var i = 0; i < repeater.count; i++) {
            var item = repeater.itemAt(i);
            if (!item) {
                return -1;
            }
            total += item.fullHeight;
            items++;
        }
        if (attributionLabel.visible) {
            total += attributionLabel.implicitHeight;
            items++;
        }
        return items > 0 ? total + blockSpacing * (items - 1) : 0;
    }

    function clearCaps() {
        attributionFits = true;
        for (var i = 0; i < repeater.count; i++) {
            var item = repeater.itemAt(i);
            if (item) {
                item.textCap = -1;
                item.visible = true;
            }
        }
    }

    /* In fixed mode the size is the user's, so anything that does not fit is
     * elided — first by capping the passage that runs over the edge, then by
     * dropping the ones after it. */
    function applyCaps() {
        attributionFits = true;

        /* The notice is not part of the repeater, so its room comes off the
         * top before the passages are allotted theirs. */
        var reserved = attributionLabel.visible
            ? blockSpacing + attributionLabel.implicitHeight
            : 0;
        var remaining = root.height - reserved;
        if (remaining < pointSize * 2) {
            attributionFits = false;
            remaining = root.height;
        }
        var dropping = false;

        for (var i = 0; i < repeater.count; i++) {
            var item = repeater.itemAt(i);
            if (!item) {
                continue;
            }
            if (dropping) {
                item.visible = false;
                continue;
            }
            var gap = i > 0 ? blockSpacing : 0;
            if (gap + item.fullHeight <= remaining) {
                item.textCap = -1;
                item.visible = true;
                remaining -= gap + item.fullHeight;
                continue;
            }
            var forText = remaining - gap - item.referenceHeight;
            if (forText >= pointSize) {         /* room for at least one line */
                item.textCap = forText;
                item.visible = true;
            } else {
                item.visible = false;
            }
            dropping = true;
        }
    }

    function relayout() {
        if (width <= 0 || height <= 0 || repeater.count === 0) {
            return;
        }
        clearCaps();

        if (!autoFit) {
            pointSize = fixedPointSize;
            applyCaps();
            return;
        }

        var low = minimumPointSize;
        var high = maximumPointSize;
        var best = minimumPointSize;
        while (low <= high) {
            var middle = (low + high) >> 1;
            pointSize = middle;
            var wanted = wantedHeight();
            if (wanted >= 0 && wanted <= height) {
                best = middle;
                low = middle + 1;
            } else {
                high = middle - 1;
            }
        }
        pointSize = best;
    }

    /* Coalesced, because several of these change together. */
    Timer {
        id: relayoutTimer
        interval: 0
        onTriggered: root.relayout()
    }

    function scheduleRelayout() {
        relayoutTimer.restart();
    }

    onWidthChanged: scheduleRelayout()
    onHeightChanged: scheduleRelayout()
    onEntriesChanged: scheduleRelayout()
    onAttributionChanged: scheduleRelayout()
    onShowReferenceChanged: scheduleRelayout()
    onAutoFitChanged: scheduleRelayout()
    onFixedPointSizeChanged: scheduleRelayout()
    onFontFamilyChanged: scheduleRelayout()
    onItalicChanged: scheduleRelayout()
    Component.onCompleted: scheduleRelayout()
}
