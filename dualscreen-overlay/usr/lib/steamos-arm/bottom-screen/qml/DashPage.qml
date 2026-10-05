// Dashboard: one screen, no scrolling. The stats on top (a skin), the
// controls you reach for while playing under them. Volume and brightness
// are Steam's (Quick Access). The AYN button opens it over whatever is on
// this screen; "Back" (or the AYN button again, or the
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
    // A minute of each reading too, for the sparklines, and this session:
    // how long the game has run and the energy it took.
    property var cpuHist: []
    property var gpuHist: []
    property var powHist: []
    property var heatHist: []
    property int sessionAppid: 0
    property double sessionStart: 0
    property double lastSample: 0
    property real energyWh: 0
    property string sessionName: ""
    property double fpsSum: 0
    property int fpsCount: 0
    function pushTo(h, v) {
        var out = h.concat([v])
        return out.length > 60 ? out.slice(out.length - 60) : out
    }
    function pushStats(n, quiet) {
        if (!n) return
        if (n.cpu) cpuHist = pushTo(cpuHist, n.cpu.load)
        if (n.gpu && n.gpu.max_mhz) gpuHist = pushTo(gpuHist, 100 * n.gpu.mhz / n.gpu.max_mhz)
        if (n.power_w !== undefined && n.power_w !== null) powHist = pushTo(powHist, Math.abs(n.power_w))
        if (n.temps && n.temps.hot !== undefined) heatHist = pushTo(heatHist, n.temps.hot)
        if (quiet) return
        var now = Date.now()
        var appid = n.game ? n.game.appid : 0
        if (appid !== sessionAppid) {
            // the game closed (or another took over): log what it was
            var minutes = sessionStart ? Math.floor((now - sessionStart) / 60000) : 0
            if (sessionAppid && minutes >= 1)
                Ui.post("/session", { appid: sessionAppid, name: sessionName, minutes: minutes, wh: energyWh,
                                      fps: fpsCount ? Math.round(fpsSum / fpsCount) : 0 })
            sessionAppid = appid
            sessionName = n.game && n.game.name ? n.game.name : ""
            fpsSum = 0
            fpsCount = 0
            sessionStart = appid ? now : 0
            energyWh = 0
        } else if (appid && lastSample && n.power_w) {
            energyWh += Math.abs(n.power_w) * Math.min(5, (now - lastSample) / 1000) / 3600
        }
        if (appid && n.fps) { fpsSum += n.fps; fpsCount++ }
        lastSample = now
    }
    function ago(t) {
        var m = Math.floor((Date.now() / 1000 - t) / 60)
        if (m < 60) return m <= 1 ? "just now" : m + " min ago"
        if (m < 1440) return Math.floor(m / 60) + " h ago"
        var d = Math.floor(m / 1440)
        return d === 1 ? "yesterday" : d + " days ago"
    }
    function minutesText(m) { return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60) + " min" }
    function sessionLine() {
        if (!sessionStart) return ""
        var m = Math.floor((Date.now() - sessionStart) / 60000)
        return (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min")
    }
    // Battery left at the draw of the last minute (steadier than now).
    function drawLine() {
        var b = st.battery
        if (!b || !b.percent || !powHist.length || b.status === "Charging") return ""
        var avg = powHist.reduce(function (a, c) { return a + c }, 0) / powHist.length
        if (avg < 0.5 || !b.energy_full_wh) return ""
        var h = b.energy_full_wh * b.percent / 100 / avg
        return Math.floor(h) + " h " + Math.round((h % 1) * 60) + " min at " + avg.toFixed(1) + " W"
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

    // The skin for the stats: from Settings, falling back to Classic if a
    // skin of the user's doesn't load.
    readonly property url classicUrl: Qt.resolvedUrl("skins/classic/Skin.qml")
    readonly property url defaultUrl: Qt.resolvedUrl("skins/pulse/Skin.qml")
    property bool skinFailed: false
    readonly property url skinUrl: skinFailed ? classicUrl : (Ui.cfg.skin_url || defaultUrl)
    onSkinUrlChanged: skinFailed = false

    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * Ui.s

        // Opened over an app: the way back.
        RowLayout {
            Layout.fillWidth: true
            visible: dash.under !== null
            spacing: 14 * Ui.s
            Btn {
                visible: dash.under !== null
                Layout.preferredHeight: 64 * Ui.s
                Layout.preferredWidth: 360 * Ui.s
                label: dash.under ? "←  Back to " + dash.under.name : ""
                fontSize: 24
                onClicked: Ui.post("/dash-done")
            }
        }

        // --------------------------------------------------- stats --
        // The look of this part is a skin: skins/<name>/Skin.qml, or the
        // user's own in ~/.local/share/steamos-arm/skins (Settings).
        Loader {
            id: skinLoader
            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.implicitHeight : 0
            source: dash.skinUrl
            onLoaded: item.dash = dash
            onStatusChanged: if (status === Loader.Error && source != dash.classicUrl) dash.skinFailed = true
        }

        // ------------------------------------------------ controls --
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: controls.implicitHeight + 44 * Ui.s
            GridLayout {
                id: controls
                anchors.fill: parent
                anchors.margins: 22 * Ui.s
                columns: 2
                columnSpacing: 18 * Ui.s
                rowSpacing: 14 * Ui.s

                component Label: Txt {
                    color: Ui.dim
                    font.pixelSize: 22 * Ui.s
                    font.weight: Font.Bold
                    font.letterSpacing: 2 * Ui.s
                    Layout.preferredWidth: 150 * Ui.s
                }

                Label { text: "PROFILE" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18 * Ui.s
                    Seg {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3
                        options: [["silent", "Silent"], ["balanced", "Balanced"], ["turbo", "Turbo"]]
                        current: dash.st.profile
                        fontSize: 24
                        onPicked: function (v) { Ui.post("/konkrd/profile-" + v) }
                    }
                    Seg {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        visible: dash.st.fan !== undefined && dash.st.fan >= 0
                        options: [["auto", "Fan auto"], ["boost", "Boost"]]
                        current: dash.st.fan_mode === "boost" ? "boost" : "auto"
                        fontSize: 24
                        onPicked: function (v) { Ui.post(v === "boost" ? "/konkrd/fan-boost-on" : "/konkrd/fan-auto") }
                    }
                }

                // This game's own settings: kept, they come back each launch.
                Label { text: "GAME"; visible: !!(dash.st.game && dash.st.game.name) }
                Btn {
                    visible: !!(dash.st.game && dash.st.game.name)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64 * Ui.s
                    active: !!(dash.st.game && dash.st.game.remembered)
                    label: active ? "✓  Saved for this game" : "Save for this game"
                    fontSize: 22
                    onClicked: Ui.post("/remember", { on: !active })
                }

                // Frame generation for the game in front (lsfg-vk), changed live.
                Label { text: "FRAME GEN"; visible: !!dash.st.fg }
                Seg {
                    Layout.fillWidth: true
                    visible: !!dash.st.fg
                    options: [[1, "Off"], [2, "2×"], [3, "3×"], [4, "4×"]]
                    current: dash.st.fg ? dash.st.fg.multiplier : 1
                    fontSize: 24
                    onPicked: function (v) { Ui.post("/fg", { multiplier: v }) }
                }

                Label { text: "REFRESH"; visible: dash.st.refresh !== undefined && dash.st.refresh !== null }
                Seg {
                    Layout.fillWidth: true
                    visible: dash.st.refresh !== undefined && dash.st.refresh !== null
                    options: {
                        var o = [[0, "Auto"]]
                        var r = dash.st.refresh ? dash.st.refresh.rates : []
                        for (var i = 0; i < r.length; i++) o.push([r[i], r[i] + " Hz"])
                        return o
                    }
                    current: dash.st.refresh ? dash.st.refresh.choice : 0
                    fontSize: 24
                    onPicked: function (v) { Ui.post("/refresh", { hz: v }) }
                }

                // Thor: the bottom screen's share of Steam's brightness.
                Label { text: "SCREEN"; visible: dash.st.dual !== undefined && dash.st.dual !== null }
                Level {
                    Layout.fillWidth: true
                    visible: dash.st.dual !== undefined && dash.st.dual !== null
                    implicitHeight: 64 * Ui.s
                    label: "Bottom"
                    minimum: 10
                    value: dash.st.dual ? dash.st.dual.bottom_share : 100
                    onMoved: function (v) { Ui.post("/brightness", { bottom_share: v }) }
                }

                Label { text: "LIGHTS"; visible: dash.st.rgb !== undefined && dash.st.rgb !== null }
                RowLayout {
                    Layout.fillWidth: true
                    visible: dash.st.rgb !== undefined && dash.st.rgb !== null
                    spacing: 12 * Ui.s
                    Repeater {
                        model: ["ff3c00", "ffb000", "40ff60", "00d0ff", "1a6bff", "a000ff", "ff2a8a", "ffffff"]
                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool current: dash.st.rgb && dash.st.rgb.mode !== "off" && dash.st.rgb.color === modelData
                            Layout.preferredWidth: 54 * Ui.s
                            Layout.preferredHeight: 54 * Ui.s
                            radius: width / 2
                            color: "#" + modelData
                            border.color: current ? Ui.text : "#33000000"
                            border.width: current ? 5 * Ui.s : 2 * Ui.s
                            scale: swTap.pressed ? 0.9 : 1
                            TapHandler {
                                id: swTap
                                onTapped: Ui.post("/rgb", { mode: dash.st.rgb && dash.st.rgb.mode === "breath" ? "breath" : "static", color: sw.modelData })
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    // The mode is one button that steps through them.
                    Btn {
                        readonly property var modes: [["static", "Steady"], ["breath", "Breathe"], ["battery", "Battery"], ["heat", "Heat"], ["off", "Off"]]
                        readonly property int at: Math.max(0, modes.findIndex(function (m) { return dash.st.rgb && m[0] === dash.st.rgb.mode }))
                        Layout.preferredWidth: 220 * Ui.s
                        Layout.preferredHeight: 58 * Ui.s
                        label: modes[at][1] + "  ›"
                        fontSize: 22
                        onClicked: Ui.post("/rgb", { mode: modes[(at + 1) % modes.length][0] })
                    }
                }
            }
        }

        // -------------------------------------------------- play log --
        // Between games: the last few sessions, what each took.
        Card {
            id: log
            readonly property var rows: dash.st.sessions || []
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: rows.length && (dash.st.fps === undefined || dash.st.fps === null) ? 1 : 0
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26 * Ui.s
                spacing: 6 * Ui.s
                Txt { text: "RECENT"; color: Ui.dim; font.pixelSize: 21 * Ui.s; font.weight: Font.Bold; font.letterSpacing: 2 * Ui.s }
                Repeater {
                    model: log.rows
                    RowLayout {
                        id: entry
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58 * Ui.s
                        spacing: 18 * Ui.s
                        Rectangle {
                            Layout.preferredWidth: 36 * Ui.s
                            Layout.preferredHeight: 50 * Ui.s
                            radius: 6 * Ui.s
                            color: Ui.line
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: entry.modelData.cover ? "file://" + entry.modelData.cover : ""
                                sourceSize: Qt.size(72, 100)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                        Txt { Layout.fillWidth: true; text: entry.modelData.name || ("App " + entry.modelData.appid); elide: Text.ElideRight; font.pixelSize: 25 * Ui.s; font.weight: Font.DemiBold }
                        Txt { text: dash.minutesText(entry.modelData.minutes); color: Ui.accent; font.pixelSize: 23 * Ui.s; font.weight: Font.Bold }
                        Txt { Layout.preferredWidth: 110 * Ui.s; horizontalAlignment: Text.AlignRight; text: entry.modelData.wh.toFixed(1) + " Wh"; color: Ui.power; font.pixelSize: 23 * Ui.s }
                        Txt { Layout.preferredWidth: 110 * Ui.s; horizontalAlignment: Text.AlignRight; text: entry.modelData.fps ? entry.modelData.fps + " fps" : ""; color: Ui.dim; font.pixelSize: 23 * Ui.s }
                        Txt { Layout.preferredWidth: 160 * Ui.s; horizontalAlignment: Text.AlignRight; text: dash.ago(entry.modelData.end); color: Ui.faint; font.pixelSize: 21 * Ui.s }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
