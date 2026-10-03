// A 0-100 level slider that owns its value while a finger is on it, and for
// a moment after (the backend reports the new level a poll later), so it
// never snaps back mid-drag. moved() is throttled to ten a second.
import QtQuick

Item {
    id: lv
    property string label
    property int value: 0            // from the backend
    property int shown: value
    property int minimum: 0
    property string unit: "%"
    property bool holding: drag.active || hold.running
    signal moved(int v)
    implicitHeight: 92 * Ui.s
    onValueChanged: if (!holding) shown = value
    Txt {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 250 * Ui.s
        text: lv.label
        color: Ui.dim
        font.pixelSize: 28 * Ui.s
        elide: Text.ElideRight
    }
    Txt {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 100 * Ui.s
        horizontalAlignment: Text.AlignRight
        text: lv.shown >= 0 ? lv.shown + lv.unit : "–"
        font.pixelSize: 28 * Ui.s
    }
    Item {
        id: area
        anchors.left: lbl.right
        anchors.right: pct.left
        anchors.rightMargin: 24 * Ui.s
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 18 * Ui.s
            radius: height / 2
            color: Ui.line
            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, lv.shown) / 100)
                height: parent.height
                radius: parent.radius
                color: Ui.accent
            }
        }
        Rectangle {
            x: track.width * Math.max(0, lv.shown) / 100 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * Ui.s
            height: width
            radius: width / 2
            color: Ui.text
        }
        function set(px) {
            var v = Math.round(Math.max(0, Math.min(1, px / track.width)) * 100)
            v = Math.max(lv.minimum, v)
            if (v === lv.shown)
                return
            lv.shown = v
            throttle.pending = v
            if (!throttle.running)
                throttle.start()
        }
        DragHandler {
            id: drag
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onCentroidChanged: if (active) area.set(centroid.position.x)
            onActiveChanged: if (!active) { throttle.stop(); lv.moved(lv.shown); hold.restart() }
        }
        TapHandler {
            onTapped: function (ev) { area.set(ev.position.x); lv.moved(lv.shown); hold.restart() }
        }
        Timer {
            id: throttle
            property int pending: 0
            interval: 100
            onTriggered: lv.moved(pending)
        }
        Timer { id: hold; interval: 2500 }
    }
}
