// Aura: one big number in the middle, two tiles beside it, rings below.
// Frosted panels and violet come from skin.json; while a game runs its
// blurred banner sits behind the number.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../.."

ColumnLayout {
    id: skin
    property var dash
    readonly property var st: dash ? dash.st : ({})
    readonly property bool playing: st.fps !== undefined && st.fps !== null
    readonly property var art: st.game && st.game.art ? st.game.art : ({})
    spacing: 16 * Ui.s

    component Tile: Card {
        id: tl
        property string k
        property string v
        property string u
        property string sub
        property color tint: Ui.accent
        Layout.fillWidth: true
        Layout.fillHeight: true
        Rectangle {               // a lit stripe down the left edge
            x: 0; y: parent.radius
            width: 5 * Ui.s; height: parent.height - 2 * parent.radius
            radius: width / 2
            color: tl.tint
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 30 * Ui.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Txt { text: tl.k; color: tl.tint; font.pixelSize: 20 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
            Row {
                spacing: 4 * Ui.s
                Txt { id: tv; text: tl.v; font.pixelSize: 58 * Ui.s; font.weight: Font.Bold }
                Txt { anchors.baseline: tv.baseline; text: tl.u; color: Ui.dim; font.pixelSize: 26 * Ui.s; font.weight: Font.DemiBold }
            }
            Txt { visible: text !== ""; text: tl.sub; color: Ui.dim; font.pixelSize: 19 * Ui.s }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 280 * Ui.s
        spacing: 16 * Ui.s

        Card {
            id: hero
            Layout.fillWidth: true
            Layout.fillHeight: true
            ArtFill {
                path: skin.playing ? (skin.art.blur || skin.art.hero || "") : ""
                radius: hero.radius
                dim: 0.55
            }
            Spark {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.leftMargin: 2 * Ui.s; anchors.rightMargin: 2 * Ui.s; anchors.bottomMargin: 2 * Ui.s
                height: parent.height * 0.2
                opacity: 0.6
                values: skin.dash ? skin.dash.fpsHist : []
                max: Math.max(30, Math.ceil(Math.max.apply(null, (skin.dash ? skin.dash.fpsHist : []).concat([1])) / 30) * 30)
                tint: Ui.accent
            }
            // what's on: the game (or the profile when nothing runs)
            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20 * Ui.s
                height: 42 * Ui.s
                width: Math.min(hero.width - 60 * Ui.s, pillText.implicitWidth + 40 * Ui.s)
                radius: height / 2
                color: Ui.accent
                Txt {
                    id: pillText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, pill.width - 30 * Ui.s)
                    elide: Text.ElideRight
                    text: skin.playing ? ((skin.st.game && skin.st.game.name) || "Playing")
                                         + (skin.dash && skin.dash.sessionLine() ? "  ·  " + skin.dash.sessionLine() : "")
                                       : (skin.dash ? skin.dash.cap(skin.st.profile) : "")
                    font.pixelSize: 20 * Ui.s
                    font.weight: Font.Bold
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: pill.bottom
                anchors.topMargin: 4 * Ui.s
                spacing: -10 * Ui.s
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * Ui.s
                    Txt {
                        id: big
                        text: skin.playing ? skin.st.fps : Qt.formatTime(new Date(), "hh:mm")
                        font.pixelSize: 124 * Ui.s
                        font.weight: Font.Black
                    }
                    Txt {
                        visible: skin.playing
                        anchors.baseline: big.baseline
                        text: "FPS"
                        color: Ui.dim
                        font.pixelSize: 30 * Ui.s
                        font.weight: Font.Bold
                    }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: skin.playing && skin.dash && skin.dash.fpsHist.length
                          ? "avg " + skin.dash.fpsAvg + "   low " + skin.dash.fpsMin
                            + (skin.st.fg && skin.st.fg.multiplier > 1 ? "   frame gen " + skin.st.fg.multiplier + "×" : "")
                          : Qt.formatDate(new Date(), "dddd d MMMM")
                    color: Ui.dim
                    font.pixelSize: 24 * Ui.s
                    font.weight: Font.DemiBold
                }
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
                sub: t.cpu !== undefined ? "CPU " + Math.round(t.cpu) + "°  GPU " + Math.round(t.gpu) + "°" : ""
            }
            Tile {
                readonly property var b: skin.st.battery || ({})
                k: b.status === "Charging" ? "CHARGING" : "BATTERY"; tint: Ui.good
                v: b.percent >= 0 ? b.percent : "–"; u: "%"
                sub: skin.dash ? (skin.dash.drawLine() || skin.dash.batteryLine()) : ""
            }
        }
    }

    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 172 * Ui.s
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16 * Ui.s
            spacing: 6 * Ui.s
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
                fraction: skin.st.power_w ? Math.min(1, Math.abs(skin.st.power_w) / 15) : 0
            }
            Ring {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "FAN"; tint: Ui.mem
                value: skin.st.fan !== undefined && skin.st.fan >= 0 ? skin.st.fan : "–"; unit: "%"
                fraction: skin.st.fan > 0 ? skin.st.fan / 100 : 0
            }
        }
    }
}
