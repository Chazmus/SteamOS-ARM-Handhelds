// Dashboard: stats on top, quick controls under them. The AYN button opens
// it over whatever is on this screen; "Back" (or the AYN button again, or the
// idle timeout in Settings) hands the screen back to that app.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: dash
    readonly property var st: Ui.st
    // The app the dashboard was opened over, if any.
    readonly property var under: {
        var u = st.nav ? st.nav.under : null
        if (!u) return null
        var r = (st.running || []).filter(function (a) { return a.id === u })
        return r.length ? r[0] : null
    }

    // Frame rate over the last minute: one sample a second while a game draws.
    property var fpsHist: []
    property int fpsAvg: 0
    property int fpsMin: 0
    function pushFps(f) {
        if (f === undefined || f === null) {
            if (fpsHist.length) fpsHist = []
            return
        }
        var h = fpsHist.concat([f])
        if (h.length > 60) h = h.slice(h.length - 60)
        fpsAvg = Math.round(h.reduce(function (a, b) { return a + b }, 0) / h.length)
        fpsMin = Math.min.apply(null, h)
        fpsHist = h
    }
    function graphPoints(w, h) {
        var top = Math.max(30, Math.ceil(Math.max.apply(null, fpsHist.concat([1])) / 30) * 30)
        var pts = []
        for (var i = 0; i < fpsHist.length; i++)
            pts.push(Qt.point(w * (60 - fpsHist.length + i) / 59, h - h * Math.min(1, fpsHist[i] / top)))
        return pts
    }
    function batteryLine() {
        var b = st.battery
        if (!b || b.percent < 0) return ""
        if (b.status === "Charging") return "charging"
        if (b.status === "Full") return "full"
        if (b.hours_left > 0) {
            var m = Math.round(b.hours_left * 60)
            return Math.floor(m / 60) + " h " + (m % 60) + " min left"
        }
        return ""
    }
    function cap(t) { return t ? t.charAt(0).toUpperCase() + t.slice(1) : "–" }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20 * Ui.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 20 * Ui.s

            // ------------------------------------------- back to the app --
            Btn {
                Layout.fillWidth: true
                Layout.preferredHeight: 84 * Ui.s
                visible: dash.under !== null
                label: dash.under ? "←  Back to " + dash.under.name : ""
                fontSize: 28
                onClicked: Ui.post("/dash-done")
            }

            // --------------------------------------------------- stats --
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

            // --------------------------------------------- Steam buttons --
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 16 * Ui.s
                Repeater {
                    model: [
                        { a: "steam", label: "Steam", icon: "go-home-symbolic" },
                        { a: "qam", label: "Quick Access", icon: "view-more-horizontal-symbolic" },
                        { a: "keyboard", label: "Steam keyboard", icon: "input-keyboard-virtual-symbolic" },
                        { a: "screenshot", label: "Screenshot", icon: "camera-photo-symbolic" }
                    ]
                    Btn {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150 * Ui.s
                        label: modelData.label
                        icon: modelData.icon
                        fontSize: 24
                        onClicked: Ui.post("/steam/" + modelData.a)
                    }
                }
            }

            // ------------------------------------------ performance + fan --
            Card {
                Layout.fillWidth: true
                implicitHeight: perf.implicitHeight + 40 * Ui.s
                ColumnLayout {
                    id: perf
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20 * Ui.s
                    spacing: 14 * Ui.s
                    Txt { text: "Performance"; color: Ui.dim; font.pixelSize: 26 * Ui.s }
                    Seg {
                        Layout.fillWidth: true
                        options: [["silent", "Silent"], ["balanced", "Balanced"], ["turbo", "Turbo"]]
                        current: dash.st.profile
                        onPicked: function (v) { Ui.post("/konkrd/profile-" + v) }
                    }
                    Txt { text: "Fan"; color: Ui.dim; font.pixelSize: 26 * Ui.s; visible: dash.st.fan !== undefined && dash.st.fan >= 0 }
                    Seg {
                        Layout.fillWidth: true
                        visible: dash.st.fan !== undefined && dash.st.fan >= 0
                        options: [["auto", "Automatic"], ["boost", "Boost"], ["fixed", "Fixed"]]
                        current: dash.st.fan_mode
                        onPicked: function (v) {
                            if (v === "auto") Ui.post("/konkrd/fan-auto")
                            else if (v === "boost") Ui.post("/konkrd/fan-boost-on")
                            else Ui.post("/konkrd/fan-fixed:" + (dash.st.fan_fixed || 50))
                        }
                    }
                    Level {
                        Layout.fillWidth: true
                        visible: dash.st.fan_mode === "fixed"
                        label: "Fan speed"
                        value: dash.st.fan_fixed !== undefined ? dash.st.fan_fixed : 50
                        onMoved: function (v) { Ui.post("/konkrd/fan-fixed:" + v) }
                    }
                    Txt {
                        text: "Refresh rate (games on the top screen)"
                        color: Ui.dim
                        font.pixelSize: 26 * Ui.s
                        visible: dash.st.refresh !== undefined && dash.st.refresh !== null
                    }
                    Seg {
                        Layout.fillWidth: true
                        visible: dash.st.refresh !== undefined && dash.st.refresh !== null
                        options: {
                            var o = [[0, "Highest"]]
                            var r = dash.st.refresh ? dash.st.refresh.rates : []
                            for (var i = 0; i < r.length; i++) o.push([r[i], r[i] + " Hz"])
                            return o
                        }
                        current: dash.st.refresh ? dash.st.refresh.choice : 0
                        onPicked: function (v) { Ui.post("/refresh", { hz: v }) }
                    }
                }
            }

            // --------------------------------------- brightness + volume --
            Card {
                Layout.fillWidth: true
                implicitHeight: levels.implicitHeight + 24 * Ui.s
                ColumnLayout {
                    id: levels
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 28 * Ui.s
                    anchors.rightMargin: 28 * Ui.s
                    anchors.topMargin: 12 * Ui.s
                    spacing: 0
                    // Thor: one level for both screens (as Steam's slider)
                    // and the bottom screen's share of it.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: dash.st.dual !== undefined && dash.st.dual !== null
                        spacing: 20 * Ui.s
                        Level {
                            Layout.fillWidth: true
                            label: "Brightness"
                            value: dash.st.dual ? dash.st.dual.level : 0
                            onMoved: function (v) { Ui.post("/brightness", { level: v }) }
                        }
                        Item { Layout.preferredWidth: 150 * Ui.s }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: dash.st.dual !== undefined && dash.st.dual !== null
                        spacing: 20 * Ui.s
                        Level {
                            Layout.fillWidth: true
                            label: "Bottom screen"
                            minimum: 10
                            value: dash.st.dual ? dash.st.dual.bottom_share : 100
                            onMoved: function (v) { Ui.post("/brightness", { bottom_share: v }) }
                        }
                        Btn {
                            Layout.preferredWidth: 150 * Ui.s
                            Layout.preferredHeight: 76 * Ui.s
                            label: "Screen off"
                            fontSize: 24
                            onClicked: Ui.post("/brightness", { bottom_on: false })
                        }
                    }
                    // Other devices: each backlight on its own.
                    Repeater {
                        model: dash.st.dual ? [] : (dash.st.backlights || [])
                        Level {
                            required property var modelData
                            Layout.fillWidth: true
                            label: modelData.label
                            value: modelData.percent
                            onMoved: function (v) { Ui.post("/brightness", { id: modelData.id, percent: v }) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20 * Ui.s
                        Level {
                            Layout.fillWidth: true
                            label: dash.st.volume && dash.st.volume.muted ? "Volume (muted)" : "Volume"
                            value: dash.st.volume ? dash.st.volume.percent : 0
                            onMoved: function (v) { Ui.post("/volume", { percent: v }) }
                        }
                        Btn {
                            Layout.preferredWidth: 150 * Ui.s
                            Layout.preferredHeight: 76 * Ui.s
                            label: dash.st.volume && dash.st.volume.muted ? "Unmute" : "Mute"
                            fontSize: 24
                            onClicked: Ui.post("/volume", { mute: "toggle" })
                        }
                    }
                }
            }

            // ------------------------------------------------ stick lights --
            Card {
                Layout.fillWidth: true
                visible: dash.st.rgb !== undefined && dash.st.rgb !== null
                implicitHeight: rgbCol.implicitHeight + 40 * Ui.s
                ColumnLayout {
                    id: rgbCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20 * Ui.s
                    anchors.leftMargin: 28 * Ui.s
                    spacing: 16 * Ui.s
                    Txt { text: "Stick lights"; color: Ui.dim; font.pixelSize: 26 * Ui.s }
                    HueSlider {
                        Layout.fillWidth: true
                        color: dash.st.rgb ? dash.st.rgb.color : "ffffff"
                        onColorPicked: function (c) {
                            Ui.post("/rgb", { mode: dash.st.rgb && dash.st.rgb.mode === "breath" ? "breath" : "static", color: c })
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14 * Ui.s
                        Repeater {
                            model: ["ff3c00", "ffb000", "40ff60", "00d0ff", "1a6bff", "a000ff", "ff2a8a", "ffffff"]
                            Rectangle {
                                id: sw
                                required property string modelData
                                readonly property bool current: dash.st.rgb && dash.st.rgb.mode !== "off" && dash.st.rgb.color === modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72 * Ui.s
                                radius: height / 2
                                color: "#" + modelData
                                border.color: current ? Ui.text : "transparent"
                                border.width: 5 * Ui.s
                                TapHandler {
                                    onTapped: Ui.post("/rgb", { mode: dash.st.rgb && dash.st.rgb.mode === "breath" ? "breath" : "static", color: sw.modelData })
                                }
                            }
                        }
                    }
                    Seg {
                        Layout.fillWidth: true
                        options: [["static", "Steady"], ["breath", "Breathing"], ["off", "Off"]]
                        current: dash.st.rgb ? dash.st.rgb.mode : ""
                        onPicked: function (v) { Ui.post("/rgb", { mode: v }) }
                    }
                    Level {
                        Layout.fillWidth: true
                        label: "Light level"
                        minimum: 5
                        value: dash.st.rgb ? Math.round(dash.st.rgb.brightness * 100 / 255) : 0
                        onMoved: function (v) { Ui.post("/rgb", { brightness: Math.round(v * 255 / 100) }) }
                    }
                }
            }
        }
    }
}
