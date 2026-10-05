// Aura: one big number on a light panel, heat and battery beside it, four
// rings below. Frosted colours and violet come from skin.json; while a game
// runs its blurred banner glows through the number's panel.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../.."

ColumnLayout {
    id: skin
    property var dash
    readonly property bool stretch: true
    // the number's panel and the rings grow into spare room, up to this
    readonly property real maxHeight: (440 + 16 + 260) * Ui.s
    readonly property var st: dash ? dash.st : ({})
    readonly property bool playing: st.fps !== undefined && st.fps !== null
    readonly property var art: st.game && st.game.art ? st.game.art : ({})
    spacing: 16 * Ui.s

    QtObject {
        id: clock
        property date now: new Date()
    }
    Timer { interval: 10000; running: !skin.playing; repeat: true; onTriggered: clock.now = new Date() }

    // A tile: its name top left, the value big in the middle, a line under.
    component Tile: Rectangle {
        id: tl
        property string k
        property string v
        property string u
        property string sub
        property color tint: Ui.accent
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 26 * Ui.s
        gradient: Gradient {
            GradientStop { position: 0; color: Ui.cardTop }
            GradientStop { position: 1; color: Ui.card }
        }
        border.color: Ui.cardEdge
        Row {
            x: 22 * Ui.s; y: 16 * Ui.s
            spacing: 8 * Ui.s
            Rectangle { width: 10 * Ui.s; height: width; radius: width / 2; color: tl.tint; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: tl.k; color: Ui.dim; font.pixelSize: 19 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 1.5 * Ui.s }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: tl.sub ? 2 * Ui.s : 8 * Ui.s
            spacing: 4 * Ui.s
            Txt { id: tv; text: tl.v; font.pixelSize: 64 * Ui.s; font.weight: Font.Bold }
            Txt { anchors.baseline: tv.baseline; text: tl.u; color: Ui.dim; font.pixelSize: 28 * Ui.s; font.weight: Font.Bold }
        }
        Txt {
            visible: tl.sub !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14 * Ui.s
            width: parent.width - 30 * Ui.s
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tl.sub
            color: Ui.dim
            font.pixelSize: 19 * Ui.s
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 340 * Ui.s
        Layout.maximumHeight: 440 * Ui.s
        Layout.preferredHeight: 360 * Ui.s
        spacing: 16 * Ui.s

        // ------------------------------------------------- the number --
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 30 * Ui.s
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Ui.cardHi, 1.35) }
                GradientStop { position: 1; color: Ui.cardHi }
            }
            border.color: Ui.cardEdge
            ArtFill {
                path: skin.playing ? (skin.art.blur || "") : ""
                radius: hero.radius
                dim: 0.45
            }
            Spark {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: 3 * Ui.s
                height: parent.height * 0.14
                opacity: 0.55
                values: skin.dash ? skin.dash.fpsHist : []
                max: Math.max(30, Math.ceil(Math.max.apply(null, (skin.dash ? skin.dash.fpsHist : []).concat([1])) / 30) * 30)
                tint: Ui.accent
            }
            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(22 * Ui.s, big.anchors.baselineOffset - 216 * Ui.s)
                height: 44 * Ui.s
                width: Math.min(hero.width - 80 * Ui.s, pillText.implicitWidth + 44 * Ui.s)
                radius: height / 2
                color: Ui.accent
                Txt {
                    id: pillText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, pill.width - 30 * Ui.s)
                    elide: Text.ElideRight
                    text: skin.playing ? ((skin.st.game && skin.st.game.name) || "Playing")
                        : (skin.dash ? skin.dash.cap(skin.st.profile) : "")
                    font.pixelSize: 20 * Ui.s
                    font.weight: Font.Bold
                }
            }
            // the number, placed by its baseline so it never meets the pill
            Txt {
                id: big
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: skin.playing ? -unit.implicitWidth / 2 - 6 * Ui.s : 0
                anchors.baseline: parent.top
                anchors.baselineOffset: Math.max(232 * Ui.s, hero.height * 0.47 + 70 * Ui.s)
                text: skin.playing ? skin.st.fps : Qt.formatTime(clock.now, "hh:mm")
                font.pixelSize: (skin.playing ? 170 : 140) * Ui.s
                font.weight: Font.Black
            }
            Txt {
                id: unit
                visible: skin.playing
                anchors.left: big.right
                anchors.leftMargin: 12 * Ui.s
                anchors.baseline: big.baseline
                text: "FPS"
                color: Ui.dim
                font.pixelSize: 34 * Ui.s
                font.weight: Font.Black
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.baseline: parent.top
                anchors.baselineOffset: big.anchors.baselineOffset + 52 * Ui.s
                text: skin.playing
                      ? [skin.dash && skin.dash.fpsHist.length ? "AVG " + skin.dash.fpsAvg + "   LOW " + skin.dash.fpsMin : "",
                         skin.dash && skin.dash.sessionLine() ? skin.dash.sessionLine().toUpperCase() : "",
                         skin.st.fg && skin.st.fg.multiplier > 1 ? "FG " + skin.st.fg.multiplier + "×" : ""]
                        .filter(function (x) { return x }).join("   ·   ")
                      : Qt.formatDate(clock.now, "dddd d MMMM").toUpperCase()
                color: Ui.dim
                font.pixelSize: 21 * Ui.s
                font.weight: Font.Bold
                font.letterSpacing: 1.5 * Ui.s
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 330 * Ui.s
            Layout.maximumWidth: 330 * Ui.s
            Layout.fillHeight: true
            spacing: 16 * Ui.s
            Tile {
                readonly property var t: skin.st.temps || ({})
                k: "HEAT"; tint: Ui.hot
                v: t.hot !== undefined ? Math.round(t.hot) : "–"; u: "°C"
                sub: t.cpu !== undefined ? "CPU " + Math.round(t.cpu) + "°   GPU " + Math.round(t.gpu) + "°" : ""
            }
            Tile {
                readonly property var b: skin.st.battery || ({})
                k: b.status === "Charging" ? "CHARGING" : "BATTERY"; tint: Ui.good
                v: b.percent >= 0 ? b.percent : "–"; u: "%"
                sub: skin.dash ? (skin.dash.drawLine() || skin.dash.batteryLine()) : ""
            }
        }
    }

    // ---------------------------------------------------------- rings --
    Card {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 212 * Ui.s
        Layout.maximumHeight: 260 * Ui.s
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14 * Ui.s
            spacing: 0
            Repeater {
                model: [
                    { k: "CPU", tint: Ui.cpu, tint2: "#6366f1", v: skin.st.cpu ? skin.st.cpu.ghz.toFixed(2) : "–", u: "GHz", f: skin.st.cpu ? skin.st.cpu.load / 100 : 0 },
                    { k: "GPU", tint: Ui.gpu, tint2: "#f472b6", v: skin.st.gpu ? "" + skin.st.gpu.mhz : "–", u: "MHz", f: skin.st.gpu && skin.st.gpu.max_mhz ? skin.st.gpu.mhz / skin.st.gpu.max_mhz : 0 },
                    { k: "POWER", tint: Ui.power, tint2: "#f97316", v: skin.st.power_w !== undefined && skin.st.power_w !== null ? Math.abs(skin.st.power_w).toFixed(1) : "–", u: "W", f: skin.st.power_w ? Math.min(1, Math.abs(skin.st.power_w) / 15) : 0 },
                    { k: "FAN", tint: Ui.mem, tint2: "#22d3ee", v: skin.st.fan !== undefined && skin.st.fan >= 0 ? "" + skin.st.fan : "–", u: "%", f: skin.st.fan > 0 ? skin.st.fan / 100 : 0 }
                ]
                Ring {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    inside: true
                    label: modelData.k
                    tint: modelData.tint
                    tint2: modelData.tint2
                    value: modelData.v
                    unit: modelData.u
                    fraction: modelData.f
                }
            }
        }
    }
}
