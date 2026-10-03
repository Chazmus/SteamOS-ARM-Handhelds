// Colour pad for the stick lights: hue across, saturation down (full colour
// at the top, white along the bottom edge). Touch or drag anywhere; the
// pick goes out at most five times a second and once more on release.
import QtQuick

Item {
    id: cp
    property string color: "ffffff"     // current, from the backend
    signal colorPicked(string rrggbb)
    implicitHeight: 170 * Ui.s

    property real hue: 0
    property real sat: 1
    function fromHex(rrggbb) {
        var c = Qt.color("#" + rrggbb)
        hue = Math.max(0, c.hsvHue)
        sat = c.hsvSaturation
    }
    Component.onCompleted: fromHex(color)
    onColorChanged: if (!drag.active && !settle.running) fromHex(color)

    function hex() {
        var c = Qt.hsva(hue, sat, 1, 1)
        function two(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return two(c.r) + two(c.g) + two(c.b)
    }
    function pickAt(x, y) {
        hue = Math.max(0, Math.min(0.999, x / field.width))
        sat = Math.max(0, Math.min(1, 1 - y / field.height))
        pending.value = hex()
        if (!pending.running) pending.start()
    }

    Rectangle {
        id: field
        anchors.fill: parent
        radius: 24 * Ui.s
        clip: true
        // Hues left to right...
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0 / 6; color: "#ff0000" }
            GradientStop { position: 1 / 6; color: "#ffff00" }
            GradientStop { position: 2 / 6; color: "#00ff00" }
            GradientStop { position: 3 / 6; color: "#00ffff" }
            GradientStop { position: 4 / 6; color: "#0000ff" }
            GradientStop { position: 5 / 6; color: "#ff00ff" }
            GradientStop { position: 6 / 6; color: "#ff0000" }
        }
        // ...fading to white towards the bottom.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00ffffff" }
                GradientStop { position: 1.0; color: "#ffffffff" }
            }
        }
    }
    Rectangle {
        x: field.width * cp.hue - width / 2
        y: field.height * (1 - cp.sat) - height / 2
        width: 56 * Ui.s
        height: width
        radius: width / 2
        color: "#" + cp.hex()
        border.color: Ui.bg
        border.width: 6 * Ui.s
        Rectangle { anchors.fill: parent; anchors.margins: -3 * Ui.s; radius: width / 2; color: "transparent"; border.color: Ui.text; border.width: 3 * Ui.s }
    }
    DragHandler {
        id: drag
        target: null
        onCentroidChanged: if (active) cp.pickAt(centroid.position.x, centroid.position.y)
        onActiveChanged: if (!active) { pending.stop(); cp.colorPicked(cp.hex()); settle.restart() }
    }
    TapHandler {
        onTapped: function (ev) { cp.pickAt(ev.position.x, ev.position.y); pending.stop(); cp.colorPicked(cp.hex()); settle.restart() }
    }
    Timer { id: pending; property string value; interval: 200; onTriggered: cp.colorPicked(value) }
    // Keep our own pick for a moment: the backend reports it a poll later.
    Timer { id: settle; interval: 2500 }
}
