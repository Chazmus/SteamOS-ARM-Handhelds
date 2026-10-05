// A reading as a ring: the arc fills to fraction. With inside: true the
// label, value and unit all sit in the ring; otherwise the label goes under
// it. Every size follows the ring's own size, so nothing touches the arc.
import QtQuick
import QtQuick.Shapes

Item {
    id: r
    property string label
    property string value
    property string unit
    property real fraction: 0
    property color tint: Ui.accent
    property color tint2: tint           // the arc's far end; a second colour makes it a sweep
    readonly property bool sweep: !Qt.colorEqual(tint, tint2)
    property bool inside: false
    property real shown: Math.max(0, Math.min(1, fraction))
    Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    implicitWidth: 230 * Ui.s
    implicitHeight: 230 * Ui.s
    readonly property real d: Math.max(10, inside ? Math.min(width, height) : Math.min(width, height - 34 * Ui.s))
    readonly property real thick: Math.max(8 * Ui.s, d * 0.075)
    // the room inside the ring, for the text
    readonly property real hole: d - 2 * thick
    Shape {
        id: shape
        width: r.d; height: r.d
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: r.inside ? parent.verticalCenter : undefined
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: Ui.line
            strokeWidth: r.thick
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: r.d / 2; centerY: r.d / 2
                radiusX: (r.d - r.thick) / 2; radiusY: radiusX
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {          // a soft glow under the lit arc
            strokeColor: Qt.rgba(r.tint.r, r.tint.g, r.tint.b, 0.22)
            strokeWidth: r.thick * 1.9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: r.d / 2; centerY: r.d / 2
                radiusX: (r.d - r.thick) / 2; radiusY: radiusX
                startAngle: 135; sweepAngle: Math.max(1, 270 * r.shown)
            }
        }
        ShapePath {
            strokeColor: r.sweep ? "transparent" : r.tint
            strokeWidth: r.thick
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: r.d / 2; centerY: r.d / 2
                radiusX: (r.d - r.thick) / 2; radiusY: radiusX
                startAngle: 135; sweepAngle: Math.max(1, 270 * r.shown)
            }
        }
    }
    // Two colours: the lit arc on a Canvas, its colour sweeping from tint at
    // the start to tint2 at the end (Shape strokes can't take a gradient).
    Canvas {
        id: arc
        visible: r.sweep
        anchors.fill: shape
        renderTarget: Canvas.Image
        property real at: r.shown
        onAtChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2, rad = (width - r.thick) / 2
            var from = 135 * Math.PI / 180, to = from + Math.max(0.01, 270 * at) * Math.PI / 180
            // conical gradients turn from 0 = 3 o'clock anticlockwise; the arc
            // starts at 135 deg clockwise, so start the colour stops there
            var g = ctx.createConicalGradient(c, c, -from)
            var span = (to - from) / (2 * Math.PI)
            g.addColorStop(0, r.tint2)
            g.addColorStop(Math.max(0.001, 1 - span), r.tint)
            g.addColorStop(1, r.tint2)
            ctx.lineWidth = r.thick
            ctx.lineCap = "round"
            ctx.strokeStyle = g
            ctx.beginPath()
            ctx.arc(c, c, rad, from, to, false)
            ctx.stroke()
        }
    }
    Column {
        anchors.centerIn: shape
        anchors.verticalCenterOffset: r.inside ? r.hole * 0.02 : 0
        width: r.hole * 0.8
        spacing: 0
        Txt {
            visible: r.inside
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: r.label
            color: r.tint
            font.pixelSize: r.hole * 0.13
            font.weight: Font.Bold
            font.letterSpacing: r.hole * 0.01
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: r.value
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 10
            font.pixelSize: r.hole * (r.inside ? 0.3 : 0.32)
            font.weight: Font.Bold
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: r.unit
            color: Ui.dim
            font.pixelSize: r.hole * 0.12
            font.weight: Font.DemiBold
        }
    }
    Txt {
        visible: !r.inside
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: r.label
        color: r.tint
        font.pixelSize: 24 * Ui.s
        font.weight: Font.Bold
        font.letterSpacing: 2 * Ui.s
    }
}
