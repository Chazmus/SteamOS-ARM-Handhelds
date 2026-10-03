// Bricks: a finger-paddle brick breaker for the bottom screen, for loading
// screens and downloads. Drag anywhere to move the paddle, tap to launch.
// Each cleared wall comes back faster with an extra row; the best score is
// kept in the bottom screen's settings.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: g
    readonly property int cols: 10
    property int rows: 4
    property int level: 1
    property int score: 0
    property int lives: 3
    property int best: Ui.cfg.bricks_best || 0
    property bool held: true            // ball sits on the paddle until a tap
    property bool over: false
    property var bricks: []              // per brick: hits left (0 = gone)
    property real bx: 0
    property real by: 0
    property real vx: 0
    property real vy: 0
    property real px: field.width / 2   // paddle centre
    readonly property real pw: 200 * Ui.s
    readonly property real ph: 26 * Ui.s
    readonly property real r: 14 * Ui.s
    readonly property real brickH: 46 * Ui.s
    readonly property real wallTop: 30 * Ui.s
    readonly property var rowColours: ["#ff6b6b", "#ff9f43", "#ffc857", "#40d080", "#1e9bff", "#c792ea"]

    function wall() {
        var b = []
        for (var i = 0; i < rows * cols; i++)
            b.push(Math.floor(i / cols) < Math.min(2, level - 1) ? 2 : 1)   // tougher top rows later on
        bricks = b
    }
    function reset(full) {
        if (full) { level = 1; score = 0; lives = 3; rows = 4; over = false }
        wall()
        held = true
    }
    function launch() {
        if (over) { reset(true); return }
        if (!held) return
        held = false
        var speed = (9 + level * 1.3) * Ui.s
        var a = (-60 - Math.random() * 60) * Math.PI / 180
        vx = Math.cos(a) * speed
        vy = Math.sin(a) * speed
    }
    function lose() {
        lives--
        if (lives <= 0) {
            over = true
            if (score > best) { best = score; Ui.setting("bricks_best", score) }
        }
        held = true
    }
    function step() {
        var w = field.width, h = field.height
        if (held) { bx = px; by = h - 60 * Ui.s - ph - r; return }
        bx += vx; by += vy
        if (bx < r) { bx = r; vx = Math.abs(vx) }
        if (bx > w - r) { bx = w - r; vx = -Math.abs(vx) }
        if (by < r) { by = r; vy = Math.abs(vy) }
        // Paddle: where it lands on the paddle steers it.
        var py = h - 60 * Ui.s - ph
        if (vy > 0 && by + r >= py && by + r <= py + ph + Math.abs(vy) && Math.abs(bx - px) <= pw / 2 + r) {
            var hit = (bx - px) / (pw / 2)
            var sp = Math.sqrt(vx * vx + vy * vy)
            var ang = (-90 + hit * 60) * Math.PI / 180
            vx = Math.cos(ang) * sp
            vy = Math.sin(ang) * sp
            by = py - r
        }
        if (by > h + r) { lose(); return }
        // Bricks: one hit per frame, bounce off the side it came from.
        var bw = w / cols
        var c = Math.floor(bx / bw), row = Math.floor((by - wallTop) / brickH)
        if (row >= 0 && row < rows && c >= 0 && c < cols) {
            var i = row * cols + c
            if (bricks[i] > 0) {
                var nb = bricks.slice()
                nb[i]--
                bricks = nb
                score += 10 * level
                var cx = c * bw + bw / 2, cy = wallTop + row * brickH + brickH / 2
                if (Math.abs(bx - cx) / bw > Math.abs(by - cy) / brickH) vx = -vx
                else vy = -vy
                if (bricks.every(function (v) { return v === 0 })) {
                    level++
                    rows = Math.min(8, rows + 1)
                    wall()
                    held = true
                }
            }
        }
    }
    Component.onCompleted: reset(true)
    Timer { interval: 16; repeat: true; running: g.visible && !g.over; onTriggered: g.step() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10 * Ui.s
        RowLayout {
            Layout.fillWidth: true
            Txt { text: "Level " + g.level; font.weight: Font.Bold; font.pixelSize: 30 * Ui.s }
            Item { Layout.fillWidth: true }
            Txt { text: "♥".repeat(Math.max(0, g.lives)); color: Ui.warn; font.pixelSize: 30 * Ui.s }
            Item { Layout.preferredWidth: 30 * Ui.s }
            Txt { text: g.score + "   best " + Math.max(g.best, g.score); color: Ui.dim; font.pixelSize: 28 * Ui.s }
        }
        Rectangle {
            id: field
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 24 * Ui.s
            color: "#05070b"
            clip: true
            Repeater {
                model: g.rows * g.cols
                Rectangle {
                    required property int index
                    readonly property int hitsLeft: g.bricks[index] || 0
                    visible: hitsLeft > 0
                    x: (index % g.cols) * field.width / g.cols + 4 * Ui.s
                    y: g.wallTop + Math.floor(index / g.cols) * g.brickH + 4 * Ui.s
                    width: field.width / g.cols - 8 * Ui.s
                    height: g.brickH - 8 * Ui.s
                    radius: 8 * Ui.s
                    color: g.rowColours[Math.floor(index / g.cols) % g.rowColours.length]
                    border.color: "white"
                    border.width: hitsLeft > 1 ? 3 * Ui.s : 0
                }
            }
            Rectangle {     // paddle
                x: g.px - g.pw / 2
                y: field.height - 60 * Ui.s - g.ph
                width: g.pw
                height: g.ph
                radius: height / 2
                color: Ui.accent
            }
            Rectangle {     // ball
                x: g.bx - g.r
                y: g.by - g.r
                width: g.r * 2
                height: width
                radius: width / 2
                color: "white"
            }
            Txt {
                anchors.centerIn: parent
                visible: g.held || g.over
                horizontalAlignment: Text.AlignHCenter
                text: g.over ? "Game over · " + g.score + "\nTap to play again" : "Tap to launch"
                color: Ui.dim
                font.pixelSize: 34 * Ui.s
            }
            DragHandler {
                target: null
                onCentroidChanged: g.px = Math.max(g.pw / 2, Math.min(field.width - g.pw / 2, centroid.position.x))
            }
            TapHandler {
                onTapped: function (ev) { g.px = Math.max(g.pw / 2, Math.min(field.width - g.pw / 2, ev.position.x)); g.launch() }
            }
        }
    }
}
