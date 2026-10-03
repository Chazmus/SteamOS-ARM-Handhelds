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

    // The skin for the stats: from Settings, falling back to Classic if a
    // skin of the user's doesn't load.
    readonly property url classicUrl: Qt.resolvedUrl("skins/classic/Skin.qml")
    property bool skinFailed: false
    readonly property url skinUrl: skinFailed || !Ui.cfg.skin_url ? classicUrl : Ui.cfg.skin_url
    onSkinUrlChanged: skinFailed = false

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

            // A game in front: keep this dashboard's settings for it. They
            // come back by themselves each time the game starts.
            RowLayout {
                Layout.fillWidth: true
                visible: !!(dash.st.game && dash.st.game.name)
                spacing: 16 * Ui.s
                Txt {
                    Layout.fillWidth: true
                    text: !dash.st.game ? "" : dash.st.game.remembered
                          ? dash.st.game.name + " starts with these settings"
                          : "Start " + dash.st.game.name + " with these settings?"
                    elide: Text.ElideRight
                    color: Ui.dim
                    font.pixelSize: 26 * Ui.s
                }
                Btn {
                    Layout.preferredWidth: 300 * Ui.s
                    Layout.preferredHeight: 76 * Ui.s
                    active: !!(dash.st.game && dash.st.game.remembered)
                    label: active ? "Saved for this game" : "Save for this game"
                    fontSize: 24
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

            // --------------------------------------------- Steam buttons --
            // (Game Mode only: in Desktop Mode Steam isn't running.)
            GridLayout {
                Layout.fillWidth: true
                visible: !dash.st.desktop
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
                    Txt {
                        text: dash.st.rgb && dash.st.rgb.mode === "battery" ? "Stick lights · following the battery (green full, red low)"
                            : dash.st.rgb && dash.st.rgb.mode === "heat" ? "Stick lights · following the chip temperature (blue cool, red hot)"
                            : "Stick lights"
                        color: Ui.dim
                        font.pixelSize: 26 * Ui.s
                    }
                    ColorPad {
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
                        options: [["static", "Steady"], ["breath", "Breathing"], ["battery", "Battery"], ["heat", "Heat"], ["off", "Off"]]
                        fontSize: 24
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
