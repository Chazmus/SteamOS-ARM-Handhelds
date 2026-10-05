// Gauges: dials. Frame rate in the middle (against the refresh rate), battery
// and temperatures either side, CPU, GPU, power and fan as small dials below.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../.."

ColumnLayout {
    id: skin
    property var dash
    readonly property var st: dash ? dash.st : ({})
    spacing: 20 * Ui.s

    component Dial: Item {
        id: d
        property real fraction: 0          // 0..1 of the arc
        property string value: "–"
        property string label: ""
        property string sub: ""
        property color tint: Ui.accent
        property real thick: 18 * Ui.s
        property real big: 64
        implicitWidth: 260 * Ui.s
        implicitHeight: implicitWidth
        // Round whatever box the layout gives it: the smaller side wins.
        readonly property real rad: Math.min(width, height) / 2 - thick
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {           // the track: 270 degrees, open at the bottom
                strokeColor: Ui.button
                strokeWidth: d.thick
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: d.width / 2; centerY: d.height / 2; radiusX: d.rad; radiusY: d.rad; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                strokeColor: d.tint
                strokeWidth: d.thick
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: d.width / 2; centerY: d.height / 2; radiusX: d.rad; radiusY: d.rad; startAngle: 135; sweepAngle: 270 * Math.max(0.005, Math.min(1, d.fraction)) }
            }
        }
        Column {
            anchors.centerIn: parent
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: d.value; font.pixelSize: d.big * Ui.s; font.weight: Font.Black }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: d.label; color: d.tint; font.pixelSize: 24 * Ui.s; font.weight: Font.Bold }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; visible: d.sub !== ""; text: d.sub; color: Ui.dim; font.pixelSize: 20 * Ui.s }
        }
    }
    function heat(t) { return t >= 85 ? Ui.warn : (t >= 70 ? "#ffc857" : Ui.good) }

    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 290 * Ui.s
        RowLayout {
            anchors.fill: parent
            anchors.margins: 20 * Ui.s
            spacing: 10 * Ui.s
            Dial {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                implicitWidth: 280 * Ui.s
                readonly property var b: skin.st.battery || ({})
                value: b.percent >= 0 ? b.percent + "%" : "–"
                label: "BATTERY"
                sub: skin.dash ? skin.dash.batteryLine() : ""
                fraction: b.percent >= 0 ? b.percent / 100 : 0
                tint: b.percent >= 0 && b.percent < 15 ? Ui.warn : Ui.good
                big: 52
            }
            Dial {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 400 * Ui.s
                readonly property int hz: skin.st.refresh && skin.st.refresh.rates && skin.st.refresh.rates.length ? Math.max.apply(null, skin.st.refresh.rates) : 60
                value: skin.st.fps !== undefined && skin.st.fps !== null ? skin.st.fps : "–"
                label: "FPS"
                sub: skin.dash && skin.dash.fpsHist.length ? "avg " + skin.dash.fpsAvg + "  ·  min " + skin.dash.fpsMin : "no game running"
                fraction: skin.st.fps ? skin.st.fps / hz : 0
                thick: 26 * Ui.s
                big: 110
            }
            Dial {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillHeight: true
                implicitWidth: 280 * Ui.s
                readonly property var t: skin.st.temps || ({})
                value: t.hot !== undefined ? t.hot + "°" : "–"
                label: "HOTTEST"
                sub: t.cpu !== undefined ? "CPU " + t.cpu + "° · GPU " + t.gpu + "°" : ""
                fraction: t.hot ? (t.hot - 30) / 70 : 0
                tint: skin.heat(t.hot || 0)
                big: 52
            }
        }
    }
    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 176 * Ui.s
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 * Ui.s
            Repeater {
                model: [
                    { label: "CPU", value: skin.st.cpu ? Ui.num(skin.st.cpu.ghz, 1) + "G" : "–", sub: skin.st.cpu ? skin.st.cpu.load + "% load" : "", f: skin.st.cpu ? skin.st.cpu.load / 100 : 0 },
                    { label: "GPU", value: skin.st.gpu ? skin.st.gpu.mhz + "" : "–", sub: "MHz", f: skin.st.gpu && skin.st.gpu.max_mhz ? skin.st.gpu.mhz / skin.st.gpu.max_mhz : 0 },
                    { label: "POWER", value: skin.st.power_w ? Ui.num(skin.st.power_w, 1) : "–", sub: "watts", f: skin.st.power_w ? skin.st.power_w / 20 : 0 },
                    { label: "MEMORY", value: skin.st.memory ? Ui.num(skin.st.memory.used_gb, 1) : "–", sub: skin.st.memory ? "of " + Ui.num(skin.st.memory.total_gb, 0) + " GB" : "", f: skin.st.memory && skin.st.memory.total_gb ? skin.st.memory.used_gb / skin.st.memory.total_gb : 0 },
                    { label: "FAN", value: skin.st.fan >= 0 ? skin.st.fan + "%" : "–", sub: skin.dash ? skin.dash.cap(skin.st.fan_mode) : "", f: skin.st.fan > 0 ? skin.st.fan / 100 : 0 }
                ]
                Dial {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 160 * Ui.s
                    thick: 12 * Ui.s
                    big: 30
                    value: modelData.value
                    label: modelData.label
                    sub: modelData.sub
                    fraction: modelData.f
                }
            }
        }
    }
}
