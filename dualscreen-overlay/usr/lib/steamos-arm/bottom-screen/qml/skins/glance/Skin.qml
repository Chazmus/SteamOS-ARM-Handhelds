// Glance: what matters first, big; the rest as rings.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../.."

ColumnLayout {
    id: skin
    property var dash           // the dashboard (see skins/README.md)
    readonly property var st: dash ? dash.st : ({})
    readonly property bool playing: st.fps !== undefined && st.fps !== null
    spacing: 18 * Ui.s

    // With no game the hero is a clock.
    QtObject {
        id: clock
        property string time: Qt.formatTime(new Date(), "hh:mm")
        property string date: Qt.formatDate(new Date(), "dddd d MMMM")
    }
    Timer {
        interval: 10000; running: !skin.playing; repeat: true
        onTriggered: { clock.time = Qt.formatTime(new Date(), "hh:mm"); clock.date = Qt.formatDate(new Date(), "dddd d MMMM") }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 330 * Ui.s
        spacing: 18 * Ui.s

        // ------------------------------------------------- the hero card --
        Card {
            id: hero
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 800 * Ui.s
            clip: true
            // The last minute's frame rate, filled, behind the number.
            Shape {
                anchors.fill: parent
                anchors.topMargin: parent.height * 0.35
                visible: skin.dash && skin.dash.fpsHist.length > 1
                opacity: 0.9
                ShapePath {
                    strokeColor: Ui.accent
                    strokeWidth: 4 * Ui.s
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: hero.height * 0.65
                        GradientStop { position: 0; color: "#551a9fff" }
                        GradientStop { position: 1; color: "#001a9fff" }
                    }
                    PathPolyline {
                        path: {
                            if (!skin.dash) return []
                            var w = hero.width, h = hero.height * 0.65
                            var p = skin.dash.graphPoints(w, h)
                            if (!p.length) return []
                            return [Qt.point(p[0].x, h)].concat(p).concat([Qt.point(p[p.length - 1].x, h)])
                        }
                    }
                }
            }
            Txt {
                x: 34 * Ui.s; y: 24 * Ui.s
                text: skin.playing ? (skin.st.game && skin.st.game.name ? skin.st.game.name : "Playing") : ""
                width: hero.width - 68 * Ui.s
                elide: Text.ElideRight
                color: Ui.dim
                font.pixelSize: 26 * Ui.s
                font.weight: Font.DemiBold
            }
            Row {
                x: 30 * Ui.s; y: 50 * Ui.s
                spacing: 14 * Ui.s
                Txt {
                    id: big
                    text: skin.playing ? skin.st.fps : clock.time
                    font.pixelSize: 150 * Ui.s
                    font.weight: Font.Black
                }
                Txt {
                    anchors.baseline: big.baseline
                    text: skin.playing ? "fps" : ""
                    color: Ui.accent
                    font.pixelSize: 46 * Ui.s
                    font.weight: Font.Bold
                }
            }
            // avg / low chips, or what the system is doing with no game.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 34 * Ui.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 30 * Ui.s
                spacing: 12 * Ui.s
                Repeater {
                    model: skin.playing && skin.dash && skin.dash.fpsHist.length
                           ? [["avg", skin.dash.fpsAvg], ["low", skin.dash.fpsMin]]
                           : [["", clock.date],
                              ["profile", skin.dash ? skin.dash.cap(skin.st.profile) : "–"]]
                    Rectangle {
                        required property var modelData
                        height: 56 * Ui.s
                        width: chipRow.implicitWidth + 36 * Ui.s
                        radius: height / 2
                        color: "#a0101722"
                        border.color: Ui.cardEdge
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 10 * Ui.s
                            Txt { text: modelData[0]; visible: text !== ""; color: Ui.dim; font.pixelSize: 22 * Ui.s; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: modelData[1]; font.pixelSize: 26 * Ui.s; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // ------------------------------------------- battery + heat cards --
        ColumnLayout {
            Layout.preferredWidth: 340 * Ui.s
            Layout.maximumWidth: 340 * Ui.s
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 18 * Ui.s
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property var b: skin.st.battery || ({})
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 30 * Ui.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4 * Ui.s
                    Txt { text: parent.parent.b.status === "Charging" ? "CHARGING" : "BATTERY"; color: Ui.good; font.pixelSize: 22 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
                    Txt { text: parent.parent.b.percent >= 0 ? parent.parent.b.percent + "%" : "–"; font.pixelSize: 58 * Ui.s; font.weight: Font.Bold }
                    Txt { text: skin.dash ? skin.dash.batteryLine() : ""; color: Ui.dim; font.pixelSize: 22 * Ui.s }
                }
            }
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property var t: skin.st.temps || ({})
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 30 * Ui.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4 * Ui.s
                    Txt { text: "HEAT"; color: Ui.hot; font.pixelSize: 22 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
                    Txt { text: parent.parent.t.hot !== undefined ? Math.round(parent.parent.t.hot) + "°" : "–"; font.pixelSize: 58 * Ui.s; font.weight: Font.Bold }
                    Txt {
                        text: (parent.parent.t.cpu !== undefined ? "CPU " + Math.round(parent.parent.t.cpu) + "°" : "")
                              + (parent.parent.t.gpu !== undefined ? "   GPU " + Math.round(parent.parent.t.gpu) + "°" : "")
                        color: Ui.dim; font.pixelSize: 22 * Ui.s
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ rings --
    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 236 * Ui.s
        RowLayout {
            anchors.fill: parent
            anchors.margins: 22 * Ui.s
            spacing: 10 * Ui.s
            Ring {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "CPU"; tint: Ui.cpu
                value: skin.st.cpu ? skin.st.cpu.ghz.toFixed(1) : "–"; unit: "GHz"
                fraction: skin.st.cpu ? skin.st.cpu.load / 100 : 0
            }
            Ring {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "GPU"; tint: Ui.gpu
                value: skin.st.gpu ? skin.st.gpu.mhz : "–"; unit: "MHz"
                fraction: skin.st.gpu && skin.st.gpu.max_mhz ? skin.st.gpu.mhz / skin.st.gpu.max_mhz : 0
            }
            Ring {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "POWER"; tint: Ui.power
                value: skin.st.power_w !== undefined && skin.st.power_w !== null ? Math.abs(skin.st.power_w).toFixed(1) : "–"; unit: "W"
                fraction: skin.st.power_w ? Math.min(1, Math.abs(skin.st.power_w) / 20) : 0
            }
            Ring {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "MEMORY"; tint: Ui.mem
                value: skin.st.memory ? skin.st.memory.used_gb.toFixed(1) : "–"; unit: "GB"
                fraction: skin.st.memory && skin.st.memory.total_gb ? skin.st.memory.used_gb / skin.st.memory.total_gb : 0
            }
        }
    }
}
