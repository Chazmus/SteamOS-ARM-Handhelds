// Bottom screen UI. Backend: ../dashboard (see Ui.qml).
//
// Pages: home (tools and apps), dash (stats and quick controls), pad/keys
// (the top screen's trackpad and keyboard), settings, apps (pick what the
// home screen shows). The backend can send the UI to a page (AYN button,
// swipe up from the bottom edge): it bumps nav.serial and the UI follows.
//
// Polling: /nav (cheap: page, app rows, bottom screen on/off) every 0.4 s so
// the AYN button answers at once; /state (all the stats) once a second, only
// while the dashboard is on screen.
//
// qml6 Main.qml -- [--shot out.png WxH [page]] api-file: save a picture of
// the UI and quit (layout checks without the device).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: root
    title: "SteamOS Bottom Screen"
    visible: true
    visibility: Window.FullScreen
    // Start at the screen's size so the first frame is already laid out.
    width: Screen.width > 0 ? Screen.width : 1240
    height: Screen.height > 0 ? Screen.height : 1080
    color: Ui.bg

    property string page: "home"
    property int navSerial: -1
    property var nav: ({})
    property var running: []
    property var pinned: []
    property var web: []
    property var hub: []
    property var recent: []
    function pollRecent() { Ui.request("GET", "/recent", undefined, function (r) { if (r && r.games) root.recent = r.games }) }
    function pollHub() { Ui.request("GET", "/hub", undefined, function (r) { if (r && r.apps) root.hub = r.apps }) }
    property bool bottomOn: true
    property string rowsKey: ""
    property string shotFile: ""
    property bool demo: false

    Binding { target: Ui; property: "s"; value: Math.min(root.width / 1240, root.height / 1080) }

    function go(p) {
        if (p === page)
            return
        page = p
        Ui.post("/nav", { page: p })
        if (p === "dash")
            pollState()
    }
    function pollNav() {
        Ui.request("GET", "/nav", undefined, function (n) {
            if (!n)
                return
            nav = n.nav || ({})
            bottomOn = n.bottom_on !== false
            if (nav.serial !== undefined && nav.serial !== navSerial && root.shotFile === "") {
                navSerial = nav.serial
                if (nav.page)
                    page = nav.page
                if (page === "dash")
                    pollState()
            }
            // Only hand the tiles a new model when the apps changed.
            var key = JSON.stringify([n.running || [], n.pinned || [], n.web || []])
            if (key !== rowsKey) {
                rowsKey = key
                running = n.running || []
                web = n.web || []
                pinned = (n.pinned || []).filter(function (p) {
                    return !(n.running || []).some(function (r) { return r.id === p.id })
                })
            }
        })
    }
    function pollState() {
        Ui.request("GET", "/state", undefined, function (n) {
            if (!n || n.hidden)
                return
            if (root.shotFile !== "" && !(n.sessions && n.sessions.length)) {   // screenshots: a play log
                var e = Date.now() / 1000
                n.sessions = [{ appid: 1546970, name: "Grand Theft Auto III", minutes: 47, wh: 5.4, fps: 55, end: e - 2400 },
                              { appid: 271590, name: "Hollow Knight", minutes: 82, wh: 7.9, fps: 60, end: e - 26000 },
                              { appid: 0, name: "Dolphin: Metroid Prime", minutes: 35, wh: 4.6, fps: 30, end: e - 95000 }]
            }
            if (root.demo) {               // screenshots of a game in progress
                var t = Date.now() / 1000
                n.fps = Math.round(58 + 3 * Math.sin(t / 3))
                n.game = { appid: 1546970, name: "Grand Theft Auto III", remembered: true }
                n.fg = { multiplier: 2, flow: 0.5, profile: true }
                n.power_w = -(7.2 + 0.8 * Math.sin(t / 5))
                n.cpu = { ghz: 2.4, load: 46 }; n.gpu = { mhz: 680, max_mhz: 1050 }
                n.temps = { cpu: 63, gpu: 58, hot: 64 }
                n.refresh = { rates: [60, 90, 120, 144], choice: 0 }
            }
            Ui.st = n
            dashPage.pushFps(n.fps)
            dashPage.pushStats(n)
            if (root.demo && dashPage.energyWh < 1) { dashPage.sessionStart = Date.now() - 47 * 60000; dashPage.energyWh = 5.4 }
        })
    }
    Connections {
        target: Ui
        function onChanged() { root.pollNav(); if (root.page === "dash" || root.page === "settings" || root.page === "home") root.pollState() }
    }
    Timer { interval: 400; running: root.shotFile === ""; repeat: true; onTriggered: root.pollNav() }
    // One-tap app tiles on home: their install state, every few seconds.
    Timer { interval: 4000; running: root.page === "home"; repeat: true; triggeredOnStart: true; onTriggered: root.pollHub() }
    Timer { interval: 30000; running: root.page === "home"; repeat: true; triggeredOnStart: true; onTriggered: root.pollRecent() }
    // Home shows the toggles and the game in front: refresh those gently.
    Timer { interval: 3000; running: root.page === "home" && root.shotFile === ""; repeat: true; onTriggered: root.pollState() }
    Timer {
        interval: 1000
        running: (root.page === "dash" || root.page === "skins") && root.shotFile === ""
        repeat: true
        onTriggered: root.pollState()
    }

    // The dashboard opened over an app steps back to it after a while
    // without a touch (Settings).
    Timer {
        id: idle
        interval: Math.max(1, Ui.cfg.dash_idle_s || 0) * 1000
        running: root.page === "dash" && (Ui.cfg.dash_idle_s || 0) > 0 && !!root.nav.under
        onTriggered: Ui.post("/dash-done")
    }
    // Any touch anywhere keeps the dashboard up (passive: takes nothing).
    Item {
        anchors.fill: parent
        z: 100
        PointHandler {
            onActiveChanged: if (active && idle.running) idle.restart()
        }
    }

    Timer {
        id: shotTimer
        interval: 2500
        onTriggered: root.contentItem.grabToImage(function (r) { r.saveToFile(root.shotFile); Qt.quit() })
    }
    Component.onCompleted: {
        var args = Qt.application.arguments
        var si = args.indexOf("--shot")
        if (si >= 0) {
            shotFile = args[si + 1]
            var wh = args[si + 2].split("x")
            root.visibility = Window.Windowed
            root.width = parseInt(wh[0])
            root.height = parseInt(wh[1])
            if (args[si + 3] && args[si + 3].indexOf("/") < 0)
                page = args[si + 3]
            if (page === "dashplay") { page = "dash"; demo = true }
            if (page === "homeplay") { page = "home"; demo = true }
            for (var i = 0; i < 58; i++) {   // a minute of history for the picture
                dashPage.pushFps(Math.round(55 + 5 * Math.sin(i / 4) - (i % 17 === 0 ? 14 : 0)))
                dashPage.pushStats({ cpu: { load: 40 + 15 * Math.sin(i / 6) }, gpu: { mhz: 600 + 120 * Math.sin(i / 5), max_mhz: 1050 },
                                     power_w: -(6.5 + 1.5 * Math.sin(i / 7)), temps: { hot: 58 + i / 10 } }, true)
            }
            shotTimer.start()
        }
        Ui.loadApi(args[args.length - 1], function () {
            root.pollNav()
            root.pollState()
            root.pollHub()
            root.pollRecent()
        })
    }

    readonly property var titles: ({
        home: "", dash: "Dashboard", pad: "Trackpad and keyboard", keys: "Trackpad and keyboard",
        settings: "Settings", apps: "Apps", notes: "Game Notes", newweb: "Web apps", hub: "Emulator Hub", skins: "Dashboard look", bricks: "Bricks"
    })

    // ------------------------------------------------------------- frame --
    // A soft light from the top so the cards sit in a space, not on black.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Ui.bgTop }
            GradientStop { position: 0.55; color: Ui.bg }
        }
    }
    Item {
        anchors.fill: parent
        anchors.margins: 24 * Ui.s

        // Status bar: home button (off the home screen), title, clock, battery.
        RowLayout {
            id: status
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 72 * Ui.s
            spacing: 24 * Ui.s
            Btn {
                visible: root.page !== "home"
                Layout.preferredWidth: 160 * Ui.s
                Layout.preferredHeight: 68 * Ui.s
                label: "⌂ Home"
                fontSize: 26
                onClicked: root.go("home")
            }
            Txt {
                text: root.titles[root.page] || ""
                font.pixelSize: 32 * Ui.s
                font.weight: Font.DemiBold
                color: Ui.dim
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            // Steam's buttons, on the dashboard (Game Mode only).
            Repeater {
                model: root.page === "dash" && !Ui.st.desktop ? [
                    ["steam", "go-home-symbolic"], ["qam", "view-more-horizontal-symbolic"],
                    ["keyboard", "input-keyboard-virtual-symbolic"], ["screenshot", "camera-photo-symbolic"]] : []
                Btn {
                    required property var modelData
                    Layout.preferredWidth: 68 * Ui.s
                    Layout.preferredHeight: 68 * Ui.s
                    icon: modelData[1]
                    iconSize: 34
                    onClicked: Ui.post("/steam/" + modelData[0])
                }
            }
            Item { Layout.preferredWidth: 6 * Ui.s; visible: root.page === "dash" }
            Txt { text: Qt.formatTime(clock.now, "hh:mm"); font.pixelSize: 36 * Ui.s; font.weight: Font.Bold }
            Txt {
                readonly property var b: Ui.st.battery
                visible: b !== undefined && b.percent >= 0
                text: b ? (b.status === "Charging" ? "⚡ " : "") + b.percent + "%" : ""
                color: b && b.percent < 15 ? Ui.warn : Ui.text
                font.pixelSize: 34 * Ui.s
                font.weight: Font.Bold
            }
        }
        QtObject {
            id: clock
            property date now: new Date()
        }
        Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { clock.now = new Date(); if (root.page !== "dash") root.pollStateLight() } }

        Item {
            id: pages
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: status.bottom
            anchors.topMargin: 18 * Ui.s
            anchors.bottom: parent.bottom

            HomePage {
                anchors.fill: parent
                visible: root.page === "home"
                running: root.running
                pinned: root.pinned
                web: root.web
                hub: root.hub
                recent: root.recent
                onOpen: function (p) { root.go(p) }
            }
            DashPage {
                id: dashPage
                anchors.fill: parent
                visible: root.page === "dash"
            }
            RemotePad {
                anchors.fill: parent
                visible: root.page === "pad" || root.page === "keys"
                mode: root.page === "keys" ? "keys" : "pad"
            }
            SkinsPage {
                anchors.fill: parent
                visible: root.page === "skins"
                dash: dashPage
            }
            SettingsPage {
                anchors.fill: parent
                visible: root.page === "settings"
                onOpen: function (p) { root.go(p) }
            }
            BricksPage {
                anchors.fill: parent
                visible: root.page === "bricks"
            }
            HubPage {
                anchors.fill: parent
                visible: root.page === "hub"
            }
            NotesPage {
                anchors.fill: parent
                visible: root.page === "notes"
            }
            NewWebPage {
                anchors.fill: parent
                visible: root.page === "newweb"
                onDone: root.go("home")
            }
            PickerPage {
                anchors.fill: parent
                visible: root.page === "apps"
                onDone: root.go("home")
            }
        }
    }
    // The battery in the status bar off the dashboard: a /state every 15 s.
    function pollStateLight() { pollState() }

    // Bottom screen switched off: black, and the first touch turns it on.
    Rectangle {
        anchors.fill: parent
        visible: !root.bottomOn
        color: "black"
        z: 200
        TapHandler { onTapped: Ui.post("/brightness", { bottom_on: true }) }
    }
}
