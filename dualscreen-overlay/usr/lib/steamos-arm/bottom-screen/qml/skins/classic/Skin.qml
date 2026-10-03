// Classic: the frame-rate graph with battery and temperatures beside it,
// and every meter under them.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../.."

ColumnLayout {
    id: skin
    property var dash           // the dashboard (see skins/README.md)
    spacing: 20 * Ui.s
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 420 * Ui.s
        spacing: 20 * Ui.s
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 700 * Ui.s
            clip: true
            Txt {
                id: fpsBig
                x: 32 * Ui.s; y: 10 * Ui.s
                text: dash.st.fps !== undefined && dash.st.fps !== null ? dash.st.fps : "–"
                font.pixelSize: 140 * Ui.s
                font.weight: Font.Black
            }
            Txt {
                anchors.left: fpsBig.right
                anchors.leftMargin: 14 * Ui.s
                anchors.baseline: fpsBig.baseline
                text: "FPS"
                color: Ui.accent
                font.pixelSize: 40 * Ui.s
                font.weight: Font.Bold
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 32 * Ui.s
                anchors.top: parent.top
                anchors.topMargin: 36 * Ui.s
                spacing: 6 * Ui.s
                Txt {
                    anchors.right: parent.right
                    text: dash.fpsHist.length ? "avg " + dash.fpsAvg : ""
                    color: Ui.dim
                    font.pixelSize: 28 * Ui.s
                }
                // The lowest one-second reading, not a frame-time low.
                Txt {
                    anchors.right: parent.right
                    text: dash.fpsHist.length ? "min " + dash.fpsMin : ""
                    color: Ui.dim
                    font.pixelSize: 28 * Ui.s
                }
            }
            Txt {
                anchors.centerIn: graph
                visible: dash.fpsHist.length === 0
                text: "No game running"
                color: Ui.dim
            }
            Item {
                id: graph
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 24 * Ui.s
                height: parent.height * 0.42
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: graph.width
                        height: 2 * Ui.s
                        y: graph.height * index / 2
                        color: Ui.line
                        opacity: 0.6
                    }
                }
                Shape {
                    anchors.fill: parent
                    visible: dash.fpsHist.length > 1
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Ui.accent
                        strokeWidth: 5 * Ui.s
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: dash.graphPoints(graph.width, graph.height) }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 300 * Ui.s
            Layout.maximumWidth: 300 * Ui.s
            Layout.fillHeight: true
            spacing: 20 * Ui.s
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Column {
                    anchors.centerIn: parent
                    spacing: 4 * Ui.s
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dash.st.battery && dash.st.battery.percent >= 0 ? dash.st.battery.percent + "%" : "–"
                        color: dash.st.battery && dash.st.battery.percent >= 0 && dash.st.battery.percent < 15 ? Ui.warn : Ui.text
                        font.pixelSize: 70 * Ui.s
                        font.weight: Font.Bold
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dash.batteryLine()
                        color: Ui.dim
                        font.pixelSize: 24 * Ui.s
                    }
                }
            }
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                GridLayout {
                    anchors.centerIn: parent
                    columns: 2
                    columnSpacing: 22 * Ui.s
                    rowSpacing: 4 * Ui.s
                    Txt { text: "CPU"; color: Ui.dim; font.pixelSize: 26 * Ui.s }
                    Txt {
                        text: dash.st.temps ? dash.st.temps.cpu + "°" : "–"
                        color: dash.st.temps && dash.st.temps.cpu >= 90 ? Ui.warn : Ui.text
                        font.pixelSize: 54 * Ui.s; font.weight: Font.Bold
                    }
                    Txt { text: "GPU"; color: Ui.dim; font.pixelSize: 26 * Ui.s }
                    Txt {
                        text: dash.st.temps ? dash.st.temps.gpu + "°" : "–"
                        color: dash.st.temps && dash.st.temps.gpu >= 90 ? Ui.warn : Ui.text
                        font.pixelSize: 54 * Ui.s; font.weight: Font.Bold
                    }
                }
            }
        }
    }
    Card {
        Layout.fillWidth: true
        implicitHeight: meters.implicitHeight + 28 * Ui.s
        GridLayout {
            id: meters
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 32 * Ui.s
            anchors.rightMargin: 32 * Ui.s
            anchors.topMargin: 18 * Ui.s
            columns: 2
            columnSpacing: 48 * Ui.s
            rowSpacing: 0
            Meter {
                Layout.fillWidth: true
                label: "CPU"
                sub: dash.st.cpu ? dash.st.cpu.load + "% load" : ""
                value: dash.st.cpu ? Ui.num(dash.st.cpu.ghz, 2) + " GHz" : "–"
                fraction: dash.st.cpu ? dash.st.cpu.load / 100 : 0
            }
            Meter {
                Layout.fillWidth: true
                label: "GPU"
                sub: dash.st.gpu && dash.st.gpu.max_mhz ? Math.round(dash.st.gpu.mhz * 100 / dash.st.gpu.max_mhz) + "% clock" : ""
                value: dash.st.gpu ? dash.st.gpu.mhz + " MHz" : "–"
                fraction: dash.st.gpu && dash.st.gpu.max_mhz ? dash.st.gpu.mhz / dash.st.gpu.max_mhz : 0
            }
            Meter {
                Layout.fillWidth: true
                label: "Power"
                value: dash.st.power_w !== undefined && dash.st.power_w !== null ? Ui.num(dash.st.power_w, 1) + " W" : "–"
                fraction: dash.st.power_w ? dash.st.power_w / 20 : 0
            }
            Meter {
                Layout.fillWidth: true
                label: "Memory"
                sub: dash.st.memory ? "of " + Ui.num(dash.st.memory.total_gb, 0) + " GB" : ""
                value: dash.st.memory ? Ui.num(dash.st.memory.used_gb, 1) + " GB" : "–"
                fraction: dash.st.memory && dash.st.memory.total_gb ? dash.st.memory.used_gb / dash.st.memory.total_gb : 0
            }
            Meter {
                Layout.fillWidth: true
                label: "Fan"
                sub: dash.st.fan_mode ? dash.cap(dash.st.fan_mode) : ""
                value: dash.st.fan !== undefined && dash.st.fan >= 0 ? dash.st.fan + "%" : "–"
                fraction: dash.st.fan > 0 ? dash.st.fan / 100 : 0
            }
            Meter {
                Layout.fillWidth: true
                label: "Network"
                sub: dash.st.net ? "↑ " + Ui.rate(dash.st.net.up) : ""
                value: dash.st.net ? "↓ " + Ui.rate(dash.st.net.down) : "–"
                fraction: dash.st.net ? Math.min(1, dash.st.net.down / 10485760) : 0
            }
        }
    }
}
