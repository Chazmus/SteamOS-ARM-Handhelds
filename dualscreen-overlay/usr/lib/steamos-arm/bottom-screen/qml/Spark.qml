// The last minute of a reading as a soft area line (values left to right,
// oldest first, scaled to max).
import QtQuick
import QtQuick.Shapes

Shape {
    id: sp
    property var values: []
    property real max: 100
    property color tint: Ui.accent
    readonly property var pts: {
        var out = [], n = values.length
        if (n < 2 || width <= 0) return out
        for (var i = 0; i < n; i++)
            out.push(Qt.point(width * i / 59 + width * (60 - n) / 59, height - height * Math.max(0, Math.min(1, values[i] / max))))
        return out
    }
    visible: pts.length > 1
    layer.enabled: true
    layer.samples: 4
    ShapePath {
        strokeColor: "transparent"
        fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: 0; y2: sp.height
            GradientStop { position: 0; color: Qt.rgba(sp.tint.r, sp.tint.g, sp.tint.b, 0.35) }
            GradientStop { position: 1; color: Qt.rgba(sp.tint.r, sp.tint.g, sp.tint.b, 0) }
        }
        PathPolyline {
            path: sp.pts.length ? [Qt.point(sp.pts[0].x, sp.height)].concat(sp.pts).concat([Qt.point(sp.pts[sp.pts.length - 1].x, sp.height)]) : []
        }
    }
    ShapePath {
        strokeColor: sp.tint
        strokeWidth: 3.5 * Ui.s
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        fillColor: "transparent"
        PathPolyline { path: sp.pts }
    }
}
