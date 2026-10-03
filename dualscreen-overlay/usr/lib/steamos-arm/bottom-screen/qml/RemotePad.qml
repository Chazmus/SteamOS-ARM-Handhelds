// Remote control for the TOP screen: a touchpad and a keyboard on the bottom
// panel. The backend turns /top/* calls into a virtual mouse and keyboard
// that only the top screen's session sees.
//
// Touchpad gestures (counted by fingers down at once):
//   1 finger      move; faster strokes travel further. Holding "Fine" moves
//                 at a third of the speed for small targets
//   tap           left click; tap, then touch and move = drag (button held
//                 until that finger lifts); tap tap = double click
//   2 fingers     scroll, with momentum after a flick (Settings); a quick
//                 two-finger tap = right click; pinch = zoom (Ctrl + wheel)
//   3 fingers     tap = middle click; swipe sideways = switch window (Alt+Tab)
//   right edge    one-finger scroll strip
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: rp
    property string mode: "pad"            // "pad" or "keys"
    readonly property real speed: Ui.cfg.pad_speed || 1.6
    readonly property bool natural: Ui.cfg.pad_natural === true
    readonly property bool momentum: Ui.cfg.momentum !== false

    onVisibleChanged: if (!visible) surface.letGo()

    ColumnLayout {
        anchors.fill: parent
        spacing: 18 * Ui.s

        Seg {
            Layout.fillWidth: true
            options: [["pad", "Touchpad"], ["keys", "Keyboard"]]
            current: rp.mode
            onPicked: function (v) { rp.mode = v }
        }

        // ------------------------------------------------------ touchpad --
        Rectangle {
            id: surface
            visible: rp.mode === "pad"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 28 * Ui.s
            color: Ui.card
            border.color: holding ? Ui.accent : Ui.line
            border.width: 2 * Ui.s

            readonly property real stripW: 96 * Ui.s
            readonly property real slop: 14 * Ui.s
            property bool fine: false
            property bool holding: false         // left button held by a drag
            // One touch, from the first finger down to the last one up.
            property int most: 0
            property bool travelled: false
            property bool fromTap: false          // started inside the click delay
            property bool inStrip: false
            property double t0: 0
            property point origin
            property point lastC
            property real spread0: 0              // pinch: finger distance at 2 fingers down
            property real swipeCarry: 0
            // Output waiting for the next frame.
            property real mx: 0
            property real my: 0
            property real wx: 0
            property real wy: 0
            // Momentum: wheel speed (notches per frame) after the fingers lift.
            property real vx: 0
            property real vy: 0

            function letGo() {
                if (holding) Ui.send("/top/click", { button: "left", state: "up" })
                holding = false
                fromTap = false
                mx = my = wx = wy = vx = vy = 0
                clickDelay.stop()
                Ui.send("/top/letgo")
            }

            Txt {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -surface.stripW / 2
                text: "Touchpad for the top screen"
                color: Ui.line
                font.pixelSize: 36 * Ui.s
            }
            // Scroll strip along the right edge.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10 * Ui.s
                width: surface.stripW - 20 * Ui.s
                radius: 20 * Ui.s
                color: surface.inStrip ? Ui.cardHi : "transparent"
                border.color: Ui.line
                border.width: 2 * Ui.s
                Txt { anchors.centerIn: parent; text: "⇅"; color: Ui.dim; font.pixelSize: 40 * Ui.s }
            }

            // A single tap clicks after this, unless a new touch starts in
            // time: then that touch drags (or a quick one double clicks).
            Timer {
                id: clickDelay
                interval: 220
                onTriggered: Ui.send("/top/click", { button: "left", state: "click" })
            }
            // Everything goes out at most once a frame.
            Timer {
                interval: 16
                repeat: true
                running: surface.mx !== 0 || surface.my !== 0 || surface.wx !== 0 || surface.wy !== 0
                         || surface.vx !== 0 || surface.vy !== 0
                onTriggered: {
                    if (surface.most === 0 && (surface.vx !== 0 || surface.vy !== 0)) {
                        surface.wx += surface.vx
                        surface.wy += surface.vy
                        surface.vx *= 0.92
                        surface.vy *= 0.92
                        if (Math.abs(surface.vx) < 0.02 && Math.abs(surface.vy) < 0.02)
                            surface.vx = surface.vy = 0
                    }
                    if (Math.abs(surface.wx) >= 1 || Math.abs(surface.wy) >= 1) {
                        Ui.send("/top/wheel", { dx: Math.trunc(surface.wx), dy: Math.trunc(surface.wy) })
                        surface.wx -= Math.trunc(surface.wx)
                        surface.wy -= Math.trunc(surface.wy)
                    } else if (surface.most === 0 && surface.vx === 0 && surface.vy === 0) {
                        surface.wx = surface.wy = 0
                    }
                    var dx = Math.round(surface.mx), dy = Math.round(surface.my)
                    if (dx !== 0 || dy !== 0) {
                        Ui.send("/top/move", { dx: dx, dy: dy })
                        surface.mx -= dx
                        surface.my -= dy
                    }
                    if (Math.abs(surface.mx) < 1 && Math.abs(surface.my) < 1 && dx === 0 && dy === 0)
                        surface.mx = surface.my = 0
                }
            }

            MultiPointTouchArea {
                id: touch
                anchors.fill: parent
                minimumTouchPoints: 1
                maximumTouchPoints: 3
                mouseEnabled: true

                function down() { return touch.touchPoints.filter(function (p) { return p.pressed }) }
                function centre(pts) {
                    if (!pts.length) return surface.lastC
                    var x = 0, y = 0
                    pts.forEach(function (p) { x += p.x; y += p.y })
                    return Qt.point(x / pts.length, y / pts.length)
                }
                function spread(pts) {
                    return pts.length >= 2 ? Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) : 0
                }
                function wheelStep() { return 40 * Ui.s }

                onPressed: {
                    var pts = down()
                    if (surface.most === 0) {
                        surface.t0 = Date.now()
                        surface.travelled = false
                        surface.origin = centre(pts)
                        surface.fromTap = clickDelay.running
                        surface.inStrip = surface.origin.x > surface.width - surface.stripW
                        surface.vx = surface.vy = 0
                        surface.swipeCarry = 0
                        clickDelay.stop()
                    }
                    surface.most = Math.max(surface.most, pts.length)
                    if (pts.length === 2) surface.spread0 = spread(pts)
                    surface.lastC = centre(pts)
                }
                onUpdated: {
                    var pts = down()
                    surface.most = Math.max(surface.most, pts.length)
                    var c = centre(pts)
                    var dx = c.x - surface.lastC.x, dy = c.y - surface.lastC.y
                    surface.lastC = c
                    if (!surface.travelled && Math.hypot(c.x - surface.origin.x, c.y - surface.origin.y) > surface.slop) {
                        surface.travelled = true
                        if (surface.fromTap && surface.most === 1 && !surface.inStrip && !surface.holding) {
                            surface.holding = true
                            Ui.send("/top/click", { button: "left", state: "down" })
                        }
                    }
                    if (!surface.travelled)
                        return
                    var k = rp.natural ? -1 : 1
                    if (surface.inStrip && pts.length === 1) {
                        surface.wy += k * dy / wheelStep()
                    } else if (pts.length === 3) {
                        // Sideways three-finger swipe: Alt+Tab per 120 px.
                        surface.swipeCarry += dx
                        while (Math.abs(surface.swipeCarry) > 120 * Ui.s) {
                            Ui.send("/top/type", { combo: surface.swipeCarry > 0 ? ["alt", "Tab"] : ["alt", "shift", "Tab"] })
                            surface.swipeCarry -= surface.swipeCarry > 0 ? 120 * Ui.s : -120 * Ui.s
                        }
                    } else if (pts.length === 2) {
                        var s = spread(pts)
                        var pinch = s - surface.spread0
                        if (Math.abs(pinch) > 2 * Math.hypot(c.x - surface.origin.x, c.y - surface.origin.y)
                                && Math.abs(pinch) >= 50 * Ui.s) {
                            // Fingers spread or close more than they travel:
                            // zoom in or out a step per 50 px.
                            var steps = Math.trunc(pinch / (50 * Ui.s))
                            for (var i = 0; i < Math.abs(steps); i++)
                                Ui.send("/top/type", { combo: ["ctrl", steps > 0 ? "=" : "-"] })
                            surface.spread0 += steps * 50 * Ui.s
                        } else {
                            surface.wx += k * dx / wheelStep()
                            surface.wy += k * dy / wheelStep()
                            surface.vx = k * dx / wheelStep()
                            surface.vy = k * dy / wheelStep()
                        }
                    } else if (pts.length === 1 && surface.most === 1) {
                        var v = Math.hypot(dx, dy) / Ui.s
                        var gain = rp.speed * (1 + Math.min(2, v / 30)) * (surface.fine ? 0.33 : 1)
                        surface.mx += dx / Ui.s * gain
                        surface.my += dy / Ui.s * gain
                    }
                }
                onReleased: {
                    if (down().length > 0)
                        return
                    var quick = Date.now() - surface.t0 < 300
                    if (surface.holding) {
                        Ui.send("/top/click", { button: "left", state: "up" })
                        surface.holding = false
                    } else if (!surface.travelled && quick && !surface.inStrip) {
                        if (surface.most >= 3)
                            Ui.send("/top/click", { button: "middle", state: "click" })
                        else if (surface.most === 2)
                            Ui.send("/top/click", { button: "right", state: "click" })
                        else if (surface.fromTap) {
                            Ui.send("/top/click", { button: "left", state: "click" })
                            Ui.send("/top/click", { button: "left", state: "click" })
                        } else
                            clickDelay.start()
                    }
                    if (!rp.momentum || surface.most !== 2)
                        surface.vx = surface.vy = 0
                    surface.most = 0
                    surface.fromTap = false
                    surface.inStrip = false
                }
                onCanceled: { surface.most = 0; surface.letGo() }
            }
        }
        RowLayout {
            visible: rp.mode === "pad"
            Layout.fillWidth: true
            Layout.preferredHeight: 140 * Ui.s
            Layout.maximumHeight: 140 * Ui.s
            spacing: 18 * Ui.s
            Repeater {
                model: [["left", "Left"], ["fine", "Fine"], ["right", "Right"]]
                Rectangle {
                    id: pb
                    required property var modelData
                    readonly property bool isFine: modelData[0] === "fine"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24 * Ui.s
                    color: hold.active ? (pb.isFine ? Qt.darker(Ui.accent, 1.9) : Ui.cardHi) : Ui.button
                    Txt { anchors.centerIn: parent; text: pb.modelData[1]; font.weight: Font.DemiBold }
                    // Held while another finger works the pad.
                    PointHandler {
                        id: hold
                        onActiveChanged: {
                            if (pb.isFine) surface.fine = active
                            else Ui.send("/top/click", { button: pb.modelData[0], state: active ? "down" : "up" })
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ keyboard --
        // Types on the top screen (whatever has focus there); the strip
        // above the keys moves the pointer without switching modes.
        Rectangle {
            id: miniPad
            visible: rp.mode === "keys"
            Layout.fillWidth: true
            Layout.preferredHeight: 190 * Ui.s
            radius: 24 * Ui.s
            color: Ui.card
            border.color: Ui.line
            border.width: 2 * Ui.s
            property point last
            Txt { anchors.centerIn: parent; text: "touchpad"; color: Ui.line; font.pixelSize: 26 * Ui.s }
            DragHandler {
                target: null
                onActiveChanged: if (active) miniPad.last = centroid.position
                onCentroidChanged: {
                    if (!active) return
                    var dx = centroid.position.x - miniPad.last.x, dy = centroid.position.y - miniPad.last.y
                    miniPad.last = centroid.position
                    Ui.send("/top/move", { dx: Math.round(dx / Ui.s * rp.speed), dy: Math.round(dy / Ui.s * rp.speed) })
                }
            }
            TapHandler { onTapped: Ui.send("/top/click", { button: "left", state: "click" }) }
        }
        KeyPad {
            visible: rp.mode === "keys"
            Layout.fillWidth: true
            Layout.fillHeight: true
            asciiOnly: true
            onTyped: function (kind, value) {
                if (kind === "combo") Ui.send("/top/type", { combo: value })
                else if (kind === "replace") Ui.send("/top/type", { replace: value })
                else if (kind === "key") Ui.send("/top/type", { key: value })
                else Ui.send("/top/type", { text: value })
            }
        }
    }
}
