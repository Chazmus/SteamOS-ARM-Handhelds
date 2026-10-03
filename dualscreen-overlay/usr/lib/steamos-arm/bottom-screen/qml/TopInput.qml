// The bottom screen as the TOP screen's trackpad and keyboard. The backend
// moves a virtual mouse and keyboard that only the top screen sees.
//
// Trackpad: one finger moves the pointer (faster strokes go further), a tap
// clicks, a two-finger tap right-clicks, a three-finger tap middle-clicks,
// two fingers scroll, and a tap followed by a touch that moves drags (the
// left button stays down until that finger lifts). The buttons along the
// bottom can be held while another finger moves.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: ti
    property string mode: "pad"            // "pad" or "keys"
    readonly property real speed: Ui.cfg.pad_speed || 1.6
    readonly property bool natural: Ui.cfg.pad_natural === true

    // Nothing stays held when the page goes away.
    onVisibleChanged: if (!visible) pad.releaseAll()

    ColumnLayout {
        anchors.fill: parent
        spacing: 18 * Ui.s

        Seg {
            Layout.fillWidth: true
            options: [["pad", "Trackpad"], ["keys", "Keyboard"]]
            current: ti.mode
            onPicked: function (v) { ti.mode = v }
        }

        // ------------------------------------------------- trackpad --
        Rectangle {
            id: pad
            visible: ti.mode === "pad"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 28 * Ui.s
            color: Ui.card
            border.color: dragging ? Ui.accent : Ui.line
            border.width: 2 * Ui.s

            readonly property int tapMs: 220
            readonly property real slop: 14 * Ui.s
            property real accX: 0
            property real accY: 0
            property real sx: 0
            property real sy: 0
            property int fingers: 0          // most fingers seen this touch
            property bool moved: false
            property double downAt: 0
            property point start
            property point last
            property bool dragging: false
            property bool dragTouch: false   // this touch started inside the tap window
            property double lastTapAt: 0

            function releaseAll() {
                if (dragging) Ui.send("/button", { button: "left", state: "up" })
                dragging = false
                dragTouch = false
                accX = accY = sx = sy = 0
                pendingClick.stop()
                Ui.send("/release")
            }

            Txt {
                anchors.centerIn: parent
                text: "Trackpad for the top screen"
                color: Ui.line
                font.pixelSize: 36 * Ui.s
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18 * Ui.s
                text: "tap: click · 2 fingers: right click / scroll · 3 fingers: middle · tap then drag: hold"
                color: Ui.line
                font.pixelSize: 22 * Ui.s
            }

            // A lone tap clicks once this runs out: a touch that starts before
            // then (and moves) turns into a drag instead of a click.
            Timer {
                id: pendingClick
                interval: pad.tapMs
                onTriggered: Ui.send("/button", { button: "left", state: "click" })
            }
            // Moves and scrolls go out at most once a frame.
            Timer {
                interval: 16
                repeat: true
                running: pad.accX !== 0 || pad.accY !== 0 || pad.sx !== 0 || pad.sy !== 0
                onTriggered: {
                    // Scrolls first: pointer moves left over from a touch's
                    // first frames must not hold a two-finger scroll back.
                    if (Math.abs(pad.sy) >= 1 || Math.abs(pad.sx) >= 1) {
                        Ui.send("/scroll", { dx: Math.trunc(pad.sx), dy: Math.trunc(pad.sy) })
                        pad.sx -= Math.trunc(pad.sx); pad.sy -= Math.trunc(pad.sy)
                    } else if (pad.fingers < 2) {
                        pad.sx = 0; pad.sy = 0
                    }
                    if (pad.accX !== 0 || pad.accY !== 0) {
                        var dx = Math.round(pad.accX), dy = Math.round(pad.accY)
                        if (dx !== 0 || dy !== 0)
                            Ui.send("/pointer", { dx: dx, dy: dy })
                        pad.accX -= dx; pad.accY -= dy
                        if (Math.abs(pad.accX) < 1 && Math.abs(pad.accY) < 1) { pad.accX = 0; pad.accY = 0 }
                    }
                }
            }

            MultiPointTouchArea {
                id: mpt
                anchors.fill: parent
                minimumTouchPoints: 1
                maximumTouchPoints: 3
                mouseEnabled: true

                function centroid(points) {
                    var x = 0, y = 0, n = 0
                    for (var i = 0; i < points.length; i++) {
                        if (!points[i].pressed) continue
                        x += points[i].x; y += points[i].y; n++
                    }
                    return n ? Qt.point(x / n, y / n) : pad.last
                }
                function active(points) {
                    var n = 0
                    for (var i = 0; i < points.length; i++) if (points[i].pressed) n++
                    return n
                }

                onPressed: function (points) {
                    var n = active(mpt.touchPoints)
                    if (pad.fingers === 0) {
                        // First finger of a new touch.
                        pad.downAt = Date.now()
                        pad.moved = false
                        pad.start = centroid(mpt.touchPoints)
                        pad.dragTouch = pendingClick.running
                        pendingClick.stop()
                    }
                    pad.fingers = Math.max(pad.fingers, n)
                    pad.last = centroid(mpt.touchPoints)
                }
                onUpdated: function (points) {
                    var n = active(mpt.touchPoints)
                    pad.fingers = Math.max(pad.fingers, n)
                    var c = centroid(mpt.touchPoints)
                    var dx = c.x - pad.last.x, dy = c.y - pad.last.y
                    pad.last = c
                    if (!pad.moved && Math.hypot(c.x - pad.start.x, c.y - pad.start.y) > pad.slop) {
                        pad.moved = true
                        if (pad.dragTouch && pad.fingers === 1 && !pad.dragging) {
                            pad.dragging = true
                            Ui.send("/button", { button: "left", state: "down" })
                        }
                    }
                    if (!pad.moved)
                        return
                    if (n >= 2) {
                        var k = ti.natural ? -1 : 1
                        pad.sx += k * dx / (40 * Ui.s)
                        pad.sy += k * dy / (40 * Ui.s)
                    } else if (n === 1 && pad.fingers === 1) {
                        // Faster strokes go further.
                        var v = Math.sqrt(dx * dx + dy * dy) / Ui.s
                        var gain = ti.speed * (1 + Math.min(2, v / 30))
                        pad.accX += dx / Ui.s * gain
                        pad.accY += dy / Ui.s * gain
                    }
                }
                onReleased: function (points) {
                    if (active(mpt.touchPoints) > 0)
                        return                  // fingers still down
                    var quick = Date.now() - pad.downAt < 300
                    if (pad.dragging) {
                        Ui.send("/button", { button: "left", state: "up" })
                        pad.dragging = false
                    } else if (!pad.moved && quick) {
                        if (pad.fingers >= 3)
                            Ui.send("/button", { button: "middle", state: "click" })
                        else if (pad.fingers === 2)
                            Ui.send("/button", { button: "right", state: "click" })
                        else if (pad.dragTouch) {
                            // Second quick tap: the first click was held back,
                            // so this is a double click.
                            Ui.send("/button", { button: "left", state: "click" })
                            Ui.send("/button", { button: "left", state: "click" })
                        } else
                            pendingClick.start()
                    }
                    pad.fingers = 0
                    pad.dragTouch = false
                }
                onCanceled: function (points) { pad.fingers = 0; pad.releaseAll() }
            }
        }
        RowLayout {
            visible: ti.mode === "pad"
            Layout.fillWidth: true
            Layout.preferredHeight: 140 * Ui.s
            Layout.maximumHeight: 140 * Ui.s
            spacing: 18 * Ui.s
            Repeater {
                model: [["left", "Left"], ["middle", "Middle"], ["right", "Right"]]
                Rectangle {
                    id: mb
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24 * Ui.s
                    color: mbp.active ? Ui.cardHi : Ui.card
                    Txt { anchors.centerIn: parent; text: mb.modelData[1]; font.weight: Font.DemiBold }
                    PointHandler {
                        id: mbp
                        onActiveChanged: Ui.send("/button", { button: mb.modelData[0], state: active ? "down" : "up" })
                    }
                }
            }
        }

        // ------------------------------------------------- keyboard --
        // Types on the top screen (whatever has focus there). The trackpad
        // strip above the keys moves the pointer without switching modes.
        Rectangle {
            visible: ti.mode === "keys"
            Layout.fillWidth: true
            Layout.preferredHeight: 190 * Ui.s
            radius: 24 * Ui.s
            color: Ui.card
            border.color: Ui.line
            border.width: 2 * Ui.s
            Txt { anchors.centerIn: parent; text: "trackpad"; color: Ui.line; font.pixelSize: 26 * Ui.s }
            property point last
            DragHandler {
                target: null
                onActiveChanged: if (active) parent.last = centroid.position
                onCentroidChanged: {
                    if (!active) return
                    var dx = centroid.position.x - parent.last.x, dy = centroid.position.y - parent.last.y
                    parent.last = centroid.position
                    Ui.send("/pointer", { dx: Math.round(dx / Ui.s * ti.speed), dy: Math.round(dy / Ui.s * ti.speed) })
                }
            }
            TapHandler { onTapped: Ui.send("/button", { button: "left", state: "click" }) }
        }
        KeyPad {
            visible: ti.mode === "keys"
            Layout.fillWidth: true
            Layout.fillHeight: true
            asciiOnly: true
            onTyped: function (kind, value) {
                if (kind === "combo") Ui.send("/key", { combo: value })
                else if (kind === "replace") Ui.send("/key", { replace: value })
                else if (kind === "key") Ui.send("/key", { key: value })
                else Ui.send("/key", { text: value })
            }
        }
    }
}
