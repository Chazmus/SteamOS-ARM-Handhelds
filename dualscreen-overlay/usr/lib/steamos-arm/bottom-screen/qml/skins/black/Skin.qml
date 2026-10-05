// Pure Black: true black, a huge frame rate, a thin trace under it and the
// numbers that matter in colour. On an AMOLED panel black pixels are off, so
// this is the one to leave up for a whole session.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../.."

Rectangle {
    id: skin
    property var dash
    readonly property var st: dash ? dash.st : ({})
    readonly property bool playing: st.fps !== undefined && st.fps !== null
    color: "black"
    radius: 24 * Ui.s
    implicitHeight: col.implicitHeight + 40 * Ui.s

    component Stat: Column {
        property string value
        property string label
        property color tint: Ui.text
        width: stats.width / 5
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.value; color: parent.tint; font.pixelSize: 64 * Ui.s; font.weight: Font.Bold }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.label; color: "#6b7280"; font.pixelSize: 22 * Ui.s; font.letterSpacing: 3 * Ui.s }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20 * Ui.s
        spacing: 10 * Ui.s
        RowLayout {
            Layout.fillWidth: true
            Txt {
                // no game: the time takes the big number's place
                text: skin.playing ? skin.st.fps : (skin.st.time || "")
                font.pixelSize: (skin.playing ? 230 : 180) * Ui.s
                font.weight: Font.Black
                color: "white"
            }
            ColumnLayout {
                visible: skin.playing
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 44 * Ui.s
                spacing: 2 * Ui.s
                Txt { text: "FPS"; color: Ui.accent; font.pixelSize: 44 * Ui.s; font.weight: Font.Bold }
                Txt {
                    text: skin.dash && skin.dash.fpsHist.length ? "avg " + skin.dash.fpsAvg + " · min " + skin.dash.fpsMin : "no game"
                    color: "#6b7280"
                    font.pixelSize: 26 * Ui.s
                }
            }
            Item { Layout.fillWidth: true }
            Txt {
                visible: skin.playing
                Layout.alignment: Qt.AlignTop
                text: skin.st.time || ""
                color: "#6b7280"
                font.pixelSize: 40 * Ui.s
            }
        }
        Item {
            id: trace
            Layout.fillWidth: true
            Layout.preferredHeight: 96 * Ui.s
            Shape {
                anchors.fill: parent
                visible: skin.dash && skin.dash.fpsHist.length > 1
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Ui.accent
                    strokeWidth: 3 * Ui.s
                    fillColor: "transparent"
                    PathPolyline { path: skin.dash ? skin.dash.graphPoints(trace.width, trace.height) : [] }
                }
            }
        }
        Row {
            id: stats
            Layout.fillWidth: true
            Layout.topMargin: 10 * Ui.s
            readonly property var b: skin.st.battery || ({})
            readonly property var t: skin.st.temps || ({})
            Stat { value: parent.b.percent >= 0 ? parent.b.percent + "%" : "–"; label: "BATTERY"; tint: parent.b.percent >= 0 && parent.b.percent < 15 ? Ui.warn : "#40d080" }
            Stat { value: parent.t.cpu !== undefined ? parent.t.cpu + "°" : "–"; label: "CPU"; tint: (parent.t.cpu || 0) >= 85 ? Ui.warn : "#ffc857" }
            Stat { value: parent.t.gpu !== undefined ? parent.t.gpu + "°" : "–"; label: "GPU"; tint: (parent.t.gpu || 0) >= 85 ? Ui.warn : "#ff9f43" }
            Stat { value: skin.st.power_w ? Ui.num(skin.st.power_w, 1) : "–"; label: "WATTS"; tint: "#7cc4ff" }
            Stat { value: skin.st.fan >= 0 ? skin.st.fan + "%" : "–"; label: "FAN"; tint: "#c792ea" }
        }
    }
}
