// Pulse: this session first, then a minute of every reading as a line.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../.."

ColumnLayout {
    id: skin
    property var dash           // the dashboard (see skins/README.md)
    readonly property var st: dash ? dash.st : ({})
    readonly property bool playing: st.fps !== undefined && st.fps !== null
    spacing: 16 * Ui.s

    QtObject {
        id: clock
        property string time: Qt.formatTime(new Date(), "hh:mm")
        property string date: Qt.formatDate(new Date(), "dddd d MMMM")
    }
    Timer {
        interval: 10000; running: !skin.playing; repeat: true
        onTriggered: { clock.time = Qt.formatTime(new Date(), "hh:mm"); clock.date = Qt.formatDate(new Date(), "dddd d MMMM") }
    }

    component Chip: Rectangle {
        id: chip
        property string k
        property string v
        height: 52 * Ui.s
        width: row.implicitWidth + 34 * Ui.s
        radius: height / 2
        color: "#b30c121b"
        border.color: Ui.cardEdge
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10 * Ui.s
            Txt { text: chip.k; visible: text !== ""; color: Ui.dim; font.pixelSize: 21 * Ui.s; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: chip.v; font.pixelSize: 25 * Ui.s; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 282 * Ui.s
        spacing: 16 * Ui.s

        // ----------------------------------------------------- session --
        Card {
            id: hero
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 800 * Ui.s
            clip: true
            Spark {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 2 * Ui.s
                anchors.rightMargin: 2 * Ui.s
                height: parent.height * 0.42
                values: skin.dash ? skin.dash.fpsHist : []
                max: Math.max(30, Math.ceil(Math.max.apply(null, (skin.dash ? skin.dash.fpsHist : []).concat([1])) / 30) * 30)
                tint: Ui.accent
            }
            RowLayout {
                x: 32 * Ui.s; y: 22 * Ui.s
                width: hero.width - 64 * Ui.s
                Txt {
                    Layout.fillWidth: true
                    text: skin.playing ? (skin.st.game && skin.st.game.name ? skin.st.game.name : "Playing") : "Ready to play"
                    elide: Text.ElideRight
                    color: Ui.dim
                    font.pixelSize: 26 * Ui.s
                    font.weight: Font.DemiBold
                }
                Txt {
                    visible: skin.playing && !!skin.dash && skin.dash.sessionLine() !== ""
                    text: skin.dash ? "▶ " + skin.dash.sessionLine() : ""
                    color: Ui.accent
                    font.pixelSize: 24 * Ui.s
                    font.weight: Font.Bold
                }
            }
            Row {
                x: 28 * Ui.s; y: 50 * Ui.s
                spacing: 12 * Ui.s
                Txt {
                    id: big
                    text: skin.playing ? skin.st.fps : clock.time
                    font.pixelSize: 120 * Ui.s
                    font.weight: Font.Black
                }
                Txt {
                    anchors.baseline: big.baseline
                    text: skin.playing ? "fps" : ""
                    color: Ui.accent
                    font.pixelSize: 42 * Ui.s
                    font.weight: Font.Bold
                }
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 32 * Ui.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26 * Ui.s
                spacing: 10 * Ui.s
                Chip { visible: !skin.playing; k: ""; v: clock.date }
                Chip { visible: !skin.playing; k: "profile"; v: skin.dash ? skin.dash.cap(skin.st.profile) : "–" }
                Chip { visible: skin.playing && !!skin.dash && skin.dash.fpsHist.length > 0; k: "avg"; v: skin.dash ? skin.dash.fpsAvg : "" }
                Chip { visible: skin.playing && !!skin.dash && skin.dash.fpsHist.length > 0; k: "low"; v: skin.dash ? skin.dash.fpsMin : "" }
                Chip { visible: skin.playing && !!skin.dash && skin.dash.energyWh > 0.05; k: "used"; v: skin.dash ? skin.dash.energyWh.toFixed(1) + " Wh" : "" }
                Chip { visible: skin.playing && !!skin.st.fg && skin.st.fg.multiplier > 1; k: "frame gen"; v: skin.st.fg ? skin.st.fg.multiplier + "×" : "" }
            }
        }

        // ----------------------------------------------------- battery --
        Card {
            id: bat
            Layout.preferredWidth: 340 * Ui.s
            Layout.maximumWidth: 340 * Ui.s
            Layout.fillHeight: true
            readonly property var b: skin.st.battery || ({})
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28 * Ui.s
                spacing: 6 * Ui.s
                Txt { text: bat.b.status === "Charging" ? "CHARGING" : "BATTERY"; color: Ui.good; font.pixelSize: 21 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
                Txt { text: bat.b.percent >= 0 ? bat.b.percent + "%" : "–"; font.pixelSize: 68 * Ui.s; font.weight: Font.Bold }
                // charge bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14 * Ui.s
                    radius: height / 2
                    color: Ui.line
                    Rectangle {
                        height: parent.height; radius: height / 2
                        width: parent.width * Math.max(0.03, (bat.b.percent || 0) / 100)
                        color: (bat.b.percent || 0) < 20 ? Ui.warn : Ui.good
                    }
                }
                Item { Layout.fillHeight: true }
                Txt { Layout.fillWidth: true; text: skin.dash ? skin.dash.batteryLine() : ""; elide: Text.ElideRight; font.pixelSize: 24 * Ui.s; font.weight: Font.DemiBold }
                Txt { Layout.fillWidth: true; text: skin.dash ? skin.dash.drawLine() : ""; visible: text !== ""; elide: Text.ElideRight; color: Ui.dim; font.pixelSize: 21 * Ui.s }
            }
        }
    }

    // ------------------------------------------------- stat sparklines --
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 168 * Ui.s
        spacing: 16 * Ui.s
        Repeater {
            model: [
                { k: "CPU", tint: Ui.cpu, v: skin.st.cpu ? skin.st.cpu.ghz.toFixed(1) : "–", u: "GHz", hist: skin.dash ? skin.dash.cpuHist : [], max: 100,
                  sub: skin.st.cpu ? Math.round(skin.st.cpu.load) + "% busy" : "" },
                { k: "GPU", tint: Ui.gpu, v: skin.st.gpu ? skin.st.gpu.mhz : "–", u: "MHz", hist: skin.dash ? skin.dash.gpuHist : [], max: 100,
                  sub: skin.st.gpu && skin.st.gpu.max_mhz ? Math.round(100 * skin.st.gpu.mhz / skin.st.gpu.max_mhz) + "% clock" : "" },
                { k: "POWER", tint: Ui.power, v: skin.st.power_w !== undefined && skin.st.power_w !== null ? Math.abs(skin.st.power_w).toFixed(1) : "–", u: "W",
                  hist: skin.dash ? skin.dash.powHist : [], max: 15, sub: skin.st.power_w < 0 ? "from battery" : "from charger" },
                { k: "HEAT", tint: Ui.hot, v: skin.st.temps && skin.st.temps.hot !== undefined ? Math.round(skin.st.temps.hot) : "–", u: "°C",
                  hist: skin.dash ? skin.dash.heatHist : [], max: 90, sub: skin.st.temps && skin.st.temps.gpu !== undefined ? "GPU " + Math.round(skin.st.temps.gpu) + "°" : "" }
            ]
            Card {
                id: tile
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Spark {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.leftMargin: 2 * Ui.s; anchors.rightMargin: 2 * Ui.s
                    height: parent.height * 0.3
                    values: tile.modelData.hist
                    max: tile.modelData.max
                    tint: tile.modelData.tint
                }
                Column {
                    x: 24 * Ui.s; y: 14 * Ui.s
                    spacing: 0
                    Txt { text: tile.modelData.k; color: tile.modelData.tint; font.pixelSize: 20 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
                    Row {
                        spacing: 6 * Ui.s
                        Txt { id: tv; text: tile.modelData.v; font.pixelSize: 44 * Ui.s; font.weight: Font.Bold }
                        Txt { anchors.baseline: tv.baseline; text: tile.modelData.u; color: Ui.dim; font.pixelSize: 22 * Ui.s; font.weight: Font.DemiBold }
                    }
                    Txt { text: tile.modelData.sub; color: Ui.dim; font.pixelSize: 19 * Ui.s }
                }
            }
        }
    }
}
