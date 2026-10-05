// A compact brightness pill: it fills in the light's own colour as far as the
// level, with the percent written on it. Drag or tap along it to set the
// level; moved() comes at most ten times a second, and the pill keeps the
// finger's value until the backend has caught up.
import QtQuick

Rectangle {
    id: dm
    property int value: 100           // 0..100, from the backend
    property color tint: Ui.accent
    property int shown: value
    readonly property bool holding: pad.pressed || settle.running
    signal moved(int v)
    implicitWidth: 220 * Ui.s
    implicitHeight: 54 * Ui.s
    radius: height / 2
    color: Ui.button
    border.color: Ui.cardEdge
    clip: true
    onValueChanged: if (!holding) shown = value
    Rectangle {
        width: Math.max(dm.height, dm.width * dm.shown / 100)
        height: dm.height
        radius: dm.radius
        color: Qt.rgba(dm.tint.r, dm.tint.g, dm.tint.b, 0.55)
    }
    Txt {
        anchors.centerIn: parent
        text: "☀  " + dm.shown + "%"
        font.pixelSize: 22 * Ui.s
        font.weight: Font.Bold
    }
    Timer { id: settle; interval: 1500 }
    Timer {
        id: throttle
        interval: 100
        property int pending: -1
        onTriggered: if (pending >= 0) { dm.moved(pending); pending = -1 }
    }
    MouseArea {
        id: pad
        anchors.fill: parent
        preventStealing: true
        function setAt(x) {
            dm.shown = Math.round(Math.max(5, Math.min(100, x / width * 100)))
            throttle.pending = dm.shown
            if (!throttle.running) throttle.start()
        }
        onPressed: function (e) { setAt(e.x) }
        onPositionChanged: function (e) { setAt(e.x) }
        onReleased: { settle.restart(); if (throttle.pending >= 0) { dm.moved(throttle.pending); throttle.pending = -1 } }
    }
}
