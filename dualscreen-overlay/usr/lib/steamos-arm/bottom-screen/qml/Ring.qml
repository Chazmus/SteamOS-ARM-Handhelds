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
            strokeColor: r.tint
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
