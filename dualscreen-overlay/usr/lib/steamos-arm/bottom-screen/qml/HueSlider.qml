// Colour slider: white at the left end, then the hues round to red again.
// colorPicked(rrggbb) while dragging, a few times a second.
import QtQuick

Item {
    id: hs
    property string color: "ffffff"     // current, from the backend
    signal colorPicked(string rrggbb)
    implicitHeight: 84 * Ui.s
    readonly property real whiteEnd: 0.08

    function hex(c) {
        function h2(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return h2(c.r) + h2(c.g) + h2(c.b)
    }
    function colorAt(f) {
        if (f <= whiteEnd)
            return Qt.rgba(1, 1, 1, 1)
        return Qt.hsva((f - whiteEnd) / (1 - whiteEnd), 1, 1, 1)
    }
    // Where the current colour sits on the bar (white, else its hue).
    function posOf(rrggbb) {
        var c = Qt.color("#" + rrggbb)
        if (c.hsvSaturation < 0.2)
            return whiteEnd / 2
        return whiteEnd + Math.max(0, c.hsvHue) * (1 - whiteEnd)
    }
    property real pos: posOf(color)
    onColorChanged: if (!drag.active && !hold.running) pos = posOf(color)

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 44 * Ui.s
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: hs.whiteEnd; color: "#ffffff" }
            GradientStop { position: hs.whiteEnd + 0.001; color: "#ff0000" }
            GradientStop { position: hs.whiteEnd + (1 - hs.whiteEnd) * 1 / 6; color: "#ffff00" }
            GradientStop { position: hs.whiteEnd + (1 - hs.whiteEnd) * 2 / 6; color: "#00ff00" }
            GradientStop { position: hs.whiteEnd + (1 - hs.whiteEnd) * 3 / 6; color: "#00ffff" }
            GradientStop { position: hs.whiteEnd + (1 - hs.whiteEnd) * 4 / 6; color: "#0000ff" }
            GradientStop { position: hs.whiteEnd + (1 - hs.whiteEnd) * 5 / 6; color: "#ff00ff" }
            GradientStop { position: 1.0; color: "#ff0000" }
        }
    }
    Rectangle {
        x: bar.width * hs.pos - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 64 * Ui.s
        height: width
        radius: width / 2
        color: hs.colorAt(hs.pos)
        border.color: Ui.text
        border.width: 5 * Ui.s
    }
    function set(px) {
        pos = Math.max(0, Math.min(1, px / bar.width))
        throttle.pending = hex(colorAt(pos))
        if (!throttle.running)
            throttle.start()
    }
    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
        onCentroidChanged: if (active) hs.set(centroid.position.x)
        onActiveChanged: if (!active) { throttle.stop(); hs.colorPicked(hs.hex(hs.colorAt(hs.pos))); hold.restart() }
    }
    TapHandler { onTapped: function (ev) { hs.set(ev.position.x); hs.colorPicked(hs.hex(hs.colorAt(hs.pos))); hold.restart() } }
    Timer { id: throttle; property string pending; interval: 200; onTriggered: hs.colorPicked(pending) }
    Timer { id: hold; interval: 2500 }
}
