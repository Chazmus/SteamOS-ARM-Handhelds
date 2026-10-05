// A reading as a ring: the arc fills to fraction, the value sits inside and
// the label under it. Colour per reading (Ui.cpu, Ui.gpu...).
import QtQuick
import QtQuick.Shapes

Item {
    id: r
    property string label
    property string value
    property string unit
    property real fraction: 0
    property color tint: Ui.accent
    property real shown: Math.max(0, Math.min(1, fraction))
    Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    implicitWidth: 230 * Ui.s
    implicitHeight: 230 * Ui.s
    readonly property real d: Math.min(width, height - 34 * Ui.s)
    readonly property real thick: 14 * Ui.s
    Shape {
        id: shape
        width: r.d; height: r.d
        anchors.horizontalCenter: parent.horizontalCenter
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
        spacing: -4 * Ui.s
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: r.value
            font.pixelSize: 40 * Ui.s
            font.weight: Font.Bold
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: r.unit
            color: Ui.dim
            font.pixelSize: 22 * Ui.s
            font.weight: Font.DemiBold
        }
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: r.label
        color: r.tint
        font.pixelSize: 24 * Ui.s
        font.weight: Font.Bold
        font.letterSpacing: 2 * Ui.s
    }
}
