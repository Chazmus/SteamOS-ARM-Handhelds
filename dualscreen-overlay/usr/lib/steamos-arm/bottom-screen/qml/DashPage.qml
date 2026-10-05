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
    readonly property url defaultUrl: Qt.resolvedUrl("skins/glance/Skin.qml")
    property bool skinFailed: false
    readonly property url skinUrl: skinFailed ? classicUrl : (Ui.cfg.skin_url || defaultUrl)
    onSkinUrlChanged: skinFailed = false

    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * Ui.s

        // Opened over an app: the way back, and this game's remembered settings.
        RowLayout {
            Layout.fillWidth: true
            visible: dash.under !== null || !!(dash.st.game && dash.st.game.name)
            spacing: 14 * Ui.s
            Btn {
                visible: dash.under !== null
                Layout.preferredHeight: 64 * Ui.s
                Layout.preferredWidth: 360 * Ui.s
                label: dash.under ? "←  Back to " + dash.under.name : ""
                fontSize: 24
                onClicked: Ui.post("/dash-done")
            }
            Item { Layout.fillWidth: true }
            Btn {
                visible: !!(dash.st.game && dash.st.game.name)
                Layout.preferredHeight: 64 * Ui.s
                Layout.preferredWidth: 380 * Ui.s
                active: !!(dash.st.game && dash.st.game.remembered)
                label: active ? "✓  Kept for " + (dash.st.game ? dash.st.game.name : "") : "Keep these for " + (dash.st.game ? dash.st.game.name : "")
                fontSize: 22
                onClicked: Ui.post("/remember", { on: !active })
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
            Layout.fillHeight: true
            GridLayout {
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
                            Layout.preferredWidth: 58 * Ui.s
                            Layout.preferredHeight: 58 * Ui.s
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
                }
                Item { Layout.preferredWidth: 1; visible: dash.st.rgb !== undefined && dash.st.rgb !== null }
                Seg {
                    Layout.fillWidth: true
                    visible: dash.st.rgb !== undefined && dash.st.rgb !== null
                    options: [["static", "Steady"], ["breath", "Breathe"], ["battery", "Battery"], ["heat", "Heat"], ["off", "Off"]]
                    fontSize: 22
                    current: dash.st.rgb ? dash.st.rgb.mode : ""
                    onPicked: function (v) { Ui.post("/rgb", { mode: v }) }
                }
                Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
            }
        }
    }
}
