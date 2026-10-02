// Bottom screen UI. Backend: ../dashboard (HTTP on 127.0.0.1).
//
// Laid out on a 1240x1080 canvas (the AYN Thor's bottom panel) and scaled by
// s to whatever the panel is (1024x768 on the AYANEO Pocket DS), so text and
// touch targets keep their size relative to the screen.
//
// Nothing here is rebuilt on a refresh: the stats are plain bindings to st,
// and the app lists only get a new model when the apps themselves change, so
// the screen doesn't flicker or jump every poll.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Window {
    id: root
    title: "SteamOS Bottom Screen"
    visible: true
    visibility: Window.FullScreen
    // Start at the screen's size so the first frame is already laid out.
    width: Screen.width > 0 ? Screen.width : 1240
    height: Screen.height > 0 ? Screen.height : 1080
    color: bg

    readonly property color bg: "#0b0f14"
    readonly property color card: "#161d26"
    readonly property color cardHi: "#223040"
    readonly property color line: "#2a3644"
    readonly property color accent: "#1a9fff"
    readonly property color textColor: "#e8eef5"
    readonly property color dimColor: "#8e9bab"
    readonly property color warn: "#ff6b6b"
    readonly property real s: Math.min(width / 1240, height / 1080)

    property string api: ""
    property string token: ""
    property var st: ({})
    property string page: "perf"
    property var runningApps: []
    property var pinnedApps: []
    property var allApps: []
    property bool picker: false
    property string appsKey: ""

    // ---------------------------------------------------------- backend --
    function request(method, path, body, done) {
        if (!api)
            return
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE && done && x.status === 200) {
                var obj = null
                try { obj = JSON.parse(x.responseText) } catch (e) { return }
                done(obj)
            }
        }
        x.open(method, api + path)
        x.setRequestHeader("X-Token", token)
        if (body !== undefined) {
            x.setRequestHeader("Content-Type", "application/json")
            x.send(JSON.stringify(body))
        } else {
            x.send()
        }
    }
    function refresh() {
        request("GET", "/state", undefined, function (n) {
            st = n
            pushFps(n.fps)
            // Only hand the app rows a new model when the apps changed.
            var key = JSON.stringify([n.running || [], n.pinned || []])
            if (key !== appsKey) {
                appsKey = key
                runningApps = n.running || []
                pinnedApps = (n.pinned || []).filter(function (p) {
                    return !(n.running || []).some(function (r) { return r.id === p.id })
                })
            }
        })
    }
    function post(path, body) { request("POST", path, body === undefined ? {} : body, function () { refresh() }) }
    // Fire and forget, for the trackpad and keys (no refresh per move).
    function send(path, body) { request("POST", path, body) }

    // qml6 Main.qml -- [--shot out.png WxH [page]] api-file: save a picture
    // of the UI and quit (layout checks without the device).
    property string shotFile: ""
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
            for (var i = 0; i < 58; i++)     // a minute of history for the picture
                pushFps(Math.round(55 + 5 * Math.sin(i / 4) - (i % 17 === 0 ? 14 : 0)))
            shotTimer.start()
        }
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE) {
                try {
                    var cfg = JSON.parse(x.responseText)
                    api = cfg.url
                    token = cfg.token
                    refresh()
                } catch (e) {}
            }
        }
        x.open("GET", "file://" + args[args.length - 1])
        x.send()
    }
    Timer { interval: 1000; running: root.page !== "pad" && root.page !== "keys"; repeat: true; onTriggered: root.refresh() }

    // Frame rate over the last minute (one sample a refresh while a game draws).
    property var fpsHist: []
    property int fpsAvg: 0
    property int fpsLow: 0
    function pushFps(f) {
        if (f === undefined || f === null) {
            if (fpsHist.length) fpsHist = []
            return
        }
        var h = fpsHist.concat([f])
        if (h.length > 60) h = h.slice(h.length - 60)
        var sorted = h.slice().sort(function (a, b) { return a - b })
        fpsAvg = Math.round(h.reduce(function (a, b) { return a + b }, 0) / h.length)
        fpsLow = sorted[Math.floor(sorted.length * 0.05)]
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
    function num(v, digits) { return v === undefined || v === null ? "–" : Number(v).toFixed(digits || 0) }

    // ------------------------------------------------------- components --
    component Label: Text {
        color: root.textColor
        font.family: "Noto Sans"
        font.pixelSize: 30 * root.s
        font.features: { "tnum": 1 }   // digits keep their width: no jitter
    }

    component Card: Rectangle {
        radius: 24 * root.s
        color: root.card
    }

    component Button: Rectangle {
        id: b
        property string label
        property string icon
        property bool active: false
        property real iconSize: 56
        property real fontSize: 28
        signal clicked()
        signal held()
        radius: 20 * root.s
        color: tap.pressed ? root.cardHi : (active ? Qt.darker(root.accent, 1.9) : root.card)
        border.color: active ? root.accent : "transparent"
        border.width: 3 * root.s
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8 * root.s
            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                visible: b.icon !== ""
                source: b.icon
                implicitWidth: b.iconSize * root.s
                implicitHeight: b.iconSize * root.s
                color: root.textColor
                isMask: true
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: b.label !== ""
                text: b.label
                font.pixelSize: b.fontSize * root.s
                font.weight: Font.DemiBold
            }
        }
        TapHandler {
            id: tap
            onTapped: b.clicked()
            onLongPressed: b.held()
        }
    }

    // A level slider that owns its value while a finger is on it, and for a
    // moment after (the backend reports the new level a poll later), so it
    // never snaps back mid-drag.
    component Level: Item {
        id: lv
        property string label
        property int value: 0            // from the backend
        property int shown: value
        property bool holding: drag.active || hold.running
        signal moved(int v)
        implicitHeight: 92 * root.s
        onValueChanged: if (!holding) shown = value
        Label {
            id: lbl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 250 * root.s
            text: lv.label
            color: root.dimColor
            font.pixelSize: 28 * root.s
            elide: Text.ElideRight
        }
        Label {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 100 * root.s
            horizontalAlignment: Text.AlignRight
            text: lv.shown >= 0 ? lv.shown + "%" : "–"
            font.pixelSize: 28 * root.s
        }
        Item {
            id: area
            anchors.left: lbl.right
            anchors.right: pct.left
            anchors.rightMargin: 24 * root.s
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18 * root.s
                radius: height / 2
                color: root.line
                Rectangle {
                    width: Math.max(height, parent.width * Math.max(0, lv.shown) / 100)
                    height: parent.height
                    radius: parent.radius
                    color: root.accent
                }
            }
            Rectangle {
                x: track.width * Math.max(0, lv.shown) / 100 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 48 * root.s
                height: width
                radius: width / 2
                color: root.textColor
            }
            function set(px) {
                var v = Math.round(Math.max(0, Math.min(1, px / track.width)) * 100)
                if (v === lv.shown)
                    return
                lv.shown = v
                throttle.pending = v
                if (!throttle.running)
                    throttle.start()
            }
            DragHandler {
                id: drag
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                onCentroidChanged: if (active) area.set(centroid.position.x)
                onActiveChanged: if (!active) { throttle.stop(); lv.moved(lv.shown); hold.restart() }
            }
            TapHandler {
                onTapped: function (ev) { area.set(ev.position.x); lv.moved(lv.shown); hold.restart() }
            }
            Timer {
                id: throttle
                property int pending: 0
                interval: 100
                onTriggered: lv.moved(pending)
            }
            Timer { id: hold; interval: 2500 }
        }
    }

    // A labelled meter: value on the right, a bar under it.
    component Meter: Item {
        id: m
        property string label
        property string value
        property string sub
        property real fraction: 0
        property color tint: root.accent
        implicitHeight: 112 * root.s
        Label {
            id: ml
            anchors.left: parent.left
            anchors.top: parent.top
            text: m.label
            color: root.dimColor
            font.pixelSize: 26 * root.s
            font.weight: Font.DemiBold
        }
        Label {
            anchors.left: ml.right
            anchors.leftMargin: 14 * root.s
            anchors.baseline: ml.baseline
            text: m.sub
            color: root.dimColor
            font.pixelSize: 22 * root.s
        }
        Label {
            anchors.right: parent.right
            anchors.baseline: ml.baseline
            text: m.value
            font.pixelSize: 40 * root.s
            font.weight: Font.Bold
        }
        Rectangle {
            id: mt
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14 * root.s
            height: 14 * root.s
            radius: height / 2
            color: root.line
            Rectangle {
                height: parent.height
                radius: parent.radius
                color: m.tint
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, m.fraction)))
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
    component AppTile: Rectangle {
        id: at
        property var app
        property bool running: false
        signal tapped()
        signal held()
        width: 200 * root.s
        height: 200 * root.s
        radius: 28 * root.s
        color: tapA.pressed ? root.cardHi : root.card
        border.color: running ? root.accent : "transparent"
        border.width: 3 * root.s
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 26 * root.s
            width: 96 * root.s
            height: 96 * root.s
            source: at.app ? at.app.icon : ""
            fallback: "application-x-executable"
            isMask: source.toString().endsWith("-symbolic")
            color: root.textColor
        }
        Label {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 20 * root.s
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: at.app ? at.app.name : ""
            font.pixelSize: 24 * root.s
        }
        TapHandler {
            id: tapA
            onTapped: at.tapped()
            onLongPressed: at.held()
        }
    }

    // ------------------------------------------------------------ frame --
    Rectangle { anchors.fill: parent; color: root.bg }

    // Page rail
    Rectangle {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 168 * root.s
        color: "#080b0f"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * root.s
            spacing: 14 * root.s
            Repeater {
                model: [
                    { id: "perf", label: "Stats", icon: "speedometer" },
                    { id: "ctl", label: "Controls", icon: "configure" },
                    { id: "apps", label: "Apps", icon: "view-app-grid-symbolic" },
                    { id: "pad", label: "Trackpad", icon: "input-touchpad-symbolic" },
                    { id: "keys", label: "Keyboard", icon: "input-keyboard-symbolic" }
                ]
                Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: modelData.label
                    icon: modelData.icon
                    iconSize: 52
                    fontSize: 22
                    active: root.page === modelData.id
                    onClicked: { root.picker = false; root.page = modelData.id }
                }
            }
        }
    }

    Item {
        id: content
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 24 * root.s

        // Status bar (every page but the trackpad and keyboard)
        RowLayout {
            id: status
            visible: root.page !== "pad" && root.page !== "keys"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: visible ? 56 * root.s : 0
            spacing: 28 * root.s
            Label { text: root.st.time || ""; font.pixelSize: 36 * root.s; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            Label {
                visible: root.st.power_w !== undefined && root.st.power_w !== null
                text: root.num(root.st.power_w, 1) + " W"
                color: root.dimColor
            }
            Label {
                text: root.st.battery && root.st.battery.percent >= 0
                      ? (root.st.battery.status === "Charging" ? "⚡ " : "") + root.st.battery.percent + "%" : ""
                color: root.st.battery && root.st.battery.percent >= 0 && root.st.battery.percent < 15 ? root.warn : root.textColor
                font.pixelSize: 34 * root.s
                font.weight: Font.Bold
            }
        }

        Item {
            id: pages
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: status.bottom
            anchors.topMargin: status.visible ? 20 * root.s : 0
            anchors.bottom: parent.bottom

            // ------------------------------------------------- stats --
            ColumnLayout {
                anchors.fill: parent
                visible: root.page === "perf"
                spacing: 20 * root.s
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 470 * root.s
                    Layout.maximumHeight: 470 * root.s
                    spacing: 20 * root.s
                    // Frame rate with the last minute as a graph.
                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 700 * root.s
                        clip: true
                        Label {
                            id: fpsBig
                            x: 32 * root.s; y: 14 * root.s
                            text: root.st.fps !== undefined && root.st.fps !== null ? root.st.fps : "–"
                            font.pixelSize: 150 * root.s
                            font.weight: Font.Black
                        }
                        Label {
                            anchors.left: fpsBig.right
                            anchors.leftMargin: 14 * root.s
                            anchors.baseline: fpsBig.baseline
                            text: "FPS"
                            color: root.accent
                            font.pixelSize: 40 * root.s
                            font.weight: Font.Bold
                        }
                        Column {
                            anchors.right: parent.right
                            anchors.rightMargin: 32 * root.s
                            anchors.top: parent.top
                            anchors.topMargin: 40 * root.s
                            spacing: 6 * root.s
                            Label {
                                anchors.right: parent.right
                                text: root.fpsHist.length ? "avg " + root.fpsAvg : ""
                                color: root.dimColor
                                font.pixelSize: 28 * root.s
                            }
                            Label {
                                anchors.right: parent.right
                                text: root.fpsHist.length ? "low " + root.fpsLow : ""
                                color: root.dimColor
                                font.pixelSize: 28 * root.s
                            }
                        }
                        Label {
                            anchors.centerIn: graph
                            visible: root.fpsHist.length === 0
                            text: "No game running"
                            color: root.dimColor
                            font.pixelSize: 30 * root.s
                        }
                        Item {
                            id: graph
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 24 * root.s
                            height: parent.height * 0.42
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    width: graph.width
                                    height: 2 * root.s
                                    y: graph.height * index / 2
                                    color: root.line
                                    opacity: 0.6
                                }
                            }
                            Shape {
                                anchors.fill: parent
                                visible: root.fpsHist.length > 1
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeColor: root.accent
                                    strokeWidth: 5 * root.s
                                    fillColor: "transparent"
                                    joinStyle: ShapePath.RoundJoin
                                    PathPolyline { path: root.graphPoints(graph.width, graph.height) }
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 300 * root.s
                        Layout.maximumWidth: 300 * root.s
                        Layout.fillHeight: true
                        spacing: 20 * root.s
                        Card {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Column {
                                anchors.centerIn: parent
                                spacing: 4 * root.s
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.st.battery && root.st.battery.percent >= 0 ? root.st.battery.percent + "%" : "–"
                                    color: root.st.battery && root.st.battery.percent >= 0 && root.st.battery.percent < 15 ? root.warn : root.textColor
                                    font.pixelSize: 70 * root.s
                                    font.weight: Font.Bold
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.batteryLine()
                                    color: root.dimColor
                                    font.pixelSize: 24 * root.s
                                }
                            }
                        }
                        Card {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            GridLayout {
                                anchors.centerIn: parent
                                columns: 2
                                columnSpacing: 22 * root.s
                                rowSpacing: 4 * root.s
                                Label { text: "CPU"; color: root.dimColor; font.pixelSize: 26 * root.s }
                                Label {
                                    text: root.st.temps ? root.st.temps.cpu + "°" : "–"
                                    color: root.st.temps && root.st.temps.cpu >= 90 ? root.warn : root.textColor
                                    font.pixelSize: 54 * root.s; font.weight: Font.Bold
                                }
                                Label { text: "GPU"; color: root.dimColor; font.pixelSize: 26 * root.s }
                                Label {
                                    text: root.st.temps ? root.st.temps.gpu + "°" : "–"
                                    color: root.st.temps && root.st.temps.gpu >= 90 ? root.warn : root.textColor
                                    font.pixelSize: 54 * root.s; font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    GridLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 32 * root.s
                        anchors.rightMargin: 32 * root.s
                        anchors.topMargin: 18 * root.s
                        anchors.bottomMargin: 10 * root.s
                        columns: 2
                        columnSpacing: 48 * root.s
                        rowSpacing: 0
                        Meter {
                            Layout.fillWidth: true
                            label: "CPU"
                            sub: root.st.cpu ? root.st.cpu.load + "% load" : ""
                            value: root.st.cpu ? root.num(root.st.cpu.ghz, 2) + " GHz" : "–"
                            fraction: root.st.cpu ? root.st.cpu.load / 100 : 0
                        }
                        Meter {
                            Layout.fillWidth: true
                            label: "GPU"
                            sub: root.st.gpu && root.st.gpu.max_mhz ? Math.round(root.st.gpu.mhz * 100 / root.st.gpu.max_mhz) + "%" : ""
                            value: root.st.gpu ? root.st.gpu.mhz + " MHz" : "–"
                            fraction: root.st.gpu && root.st.gpu.max_mhz ? root.st.gpu.mhz / root.st.gpu.max_mhz : 0
                        }
                        Meter {
                            Layout.fillWidth: true
                            label: "Power"
                            value: root.st.power_w !== undefined && root.st.power_w !== null ? root.num(root.st.power_w, 1) + " W" : "–"
                            fraction: root.st.power_w ? root.st.power_w / 20 : 0
                        }
                        Meter {
                            Layout.fillWidth: true
                            label: "Memory"
                            sub: root.st.memory ? "of " + root.num(root.st.memory.total_gb, 0) + " GB" : ""
                            value: root.st.memory ? root.num(root.st.memory.used_gb, 1) + " GB" : "–"
                            fraction: root.st.memory && root.st.memory.total_gb ? root.st.memory.used_gb / root.st.memory.total_gb : 0
                        }
                        Meter {
                            Layout.fillWidth: true
                            label: "Fan"
                            value: root.st.fan !== undefined && root.st.fan >= 0 ? root.st.fan + "%" : "–"
                            fraction: root.st.fan > 0 ? root.st.fan / 100 : 0
                        }
                        Meter {
                            Layout.fillWidth: true
                            label: "Profile"
                            value: root.st.profile ? root.st.profile.charAt(0).toUpperCase() + root.st.profile.slice(1) : "–"
                            fraction: root.st.profile === "turbo" ? 1 : root.st.profile === "balanced" ? 0.6 : 0.3
                        }
                    }
                }
            }
            // ---------------------------------------------- controls --
            Flickable {
                anchors.fill: parent
                visible: root.page === "ctl"
                contentHeight: ctl.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: ctl
                    width: parent.width
                    spacing: 20 * root.s
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 16 * root.s
                        Repeater {
                            model: [
                                { a: "steam", label: "Steam", icon: "go-home-symbolic" },
                                { a: "qam", label: "Quick Access", icon: "view-more-horizontal-symbolic" },
                                { a: "keyboard", label: "Steam keyboard", icon: "input-keyboard-virtual-symbolic" },
                                { a: "screenshot", label: "Screenshot", icon: "camera-photo-symbolic" }
                            ]
                            Button {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150 * root.s
                                label: modelData.label
                                icon: modelData.icon
                                fontSize: 24
                                onClicked: root.post("/steam/" + modelData.a)
                            }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: perfRow.implicitHeight + 32 * root.s
                        RowLayout {
                            id: perfRow
                            anchors.fill: parent
                            anchors.margins: 16 * root.s
                            spacing: 12 * root.s
                            Repeater {
                                model: [["silent", "Silent"], ["balanced", "Balanced"], ["turbo", "Turbo"]]
                                Button {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 96 * root.s
                                    label: modelData[1]
                                    active: root.st.profile === modelData[0]
                                    onClicked: root.post("/konkrd/profile-" + modelData[0])
                                }
                            }
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 96 * root.s
                                label: "Fan boost"
                                active: root.st.fan_boost === true
                                onClicked: root.post("/konkrd/fan-boost")
                            }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: levels.implicitHeight + 24 * root.s
                        ColumnLayout {
                            id: levels
                            anchors.fill: parent
                            anchors.leftMargin: 28 * root.s
                            anchors.rightMargin: 28 * root.s
                            anchors.topMargin: 12 * root.s
                            anchors.bottomMargin: 12 * root.s
                            spacing: 0
                            // Thor: one level for both screens (as Steam's
                            // slider), and the bottom screen's share of it.
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.st.dual !== undefined && root.st.dual !== null
                                spacing: 20 * root.s
                                Level {
                                    Layout.fillWidth: true
                                    label: "Brightness"
                                    value: root.st.dual ? root.st.dual.level : 0
                                    onMoved: function (v) { root.post("/brightness", { level: v }) }
                                }
                                Item { Layout.preferredWidth: 150 * root.s }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.st.dual !== undefined && root.st.dual !== null
                                spacing: 20 * root.s
                                Level {
                                    Layout.fillWidth: true
                                    label: "Bottom screen"
                                    value: root.st.dual ? root.st.dual.bottom_share : 100
                                    onMoved: function (v) { root.post("/brightness", { bottom_share: Math.max(10, v) }) }
                                }
                                Button {
                                    Layout.preferredWidth: 150 * root.s
                                    Layout.preferredHeight: 76 * root.s
                                    label: "Screen off"
                                    fontSize: 24
                                    onClicked: root.post("/brightness", { bottom_on: false })
                                }
                            }
                            // Other devices: each backlight on its own.
                            Repeater {
                                model: root.st.dual ? [] : (root.st.backlights || [])
                                Level {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.label
                                    value: modelData.percent
                                    onMoved: function (v) { root.post("/brightness", { id: modelData.id, percent: v }) }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20 * root.s
                                Level {
                                    Layout.fillWidth: true
                                    label: root.st.volume && root.st.volume.muted ? "Volume (muted)" : "Volume"
                                    value: root.st.volume ? root.st.volume.percent : 0
                                    onMoved: function (v) { root.post("/volume", { percent: v }) }
                                }
                                Button {
                                    Layout.preferredWidth: 150 * root.s
                                    Layout.preferredHeight: 76 * root.s
                                    label: root.st.volume && root.st.volume.muted ? "Unmute" : "Mute"
                                    fontSize: 24
                                    onClicked: root.post("/volume", { mute: "toggle" })
                                }
                            }
                        }
                    }
                    // Stick lights (AYN Thor, KONKR)
                    Card {
                        Layout.fillWidth: true
                        visible: root.st.rgb !== undefined && root.st.rgb !== null
                        implicitHeight: rgbCol.implicitHeight + 40 * root.s
                        ColumnLayout {
                            id: rgbCol
                            anchors.fill: parent
                            anchors.margins: 20 * root.s
                            anchors.leftMargin: 28 * root.s
                            spacing: 16 * root.s
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14 * root.s
                                Label { text: "Stick lights"; color: root.dimColor; font.pixelSize: 28 * root.s; Layout.preferredWidth: 236 * root.s }
                                Repeater {
                                    model: ["ff3c00", "ffb000", "40ff60", "00d0ff", "1a6bff", "a000ff", "ff2a8a", "ffffff"]
                                    Rectangle {
                                        id: sw
                                        required property string modelData
                                        readonly property bool current: root.st.rgb && root.st.rgb.mode !== "off" && root.st.rgb.color === modelData
                                        Layout.preferredWidth: 72 * root.s
                                        Layout.preferredHeight: 72 * root.s
                                        radius: width / 2
                                        color: "#" + modelData
                                        border.color: current ? root.textColor : "transparent"
                                        border.width: 5 * root.s
                                        TapHandler {
                                            onTapped: root.post("/rgb", { mode: root.st.rgb && root.st.rgb.mode === "breath" ? "breath" : "static", color: sw.modelData })
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12 * root.s
                                Repeater {
                                    model: [["static", "Steady"], ["breath", "Breathing"], ["off", "Off"]]
                                    Button {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 80 * root.s
                                        label: modelData[1]
                                        fontSize: 26
                                        active: root.st.rgb !== undefined && root.st.rgb !== null && root.st.rgb.mode === modelData[0]
                                        onClicked: root.post("/rgb", { mode: modelData[0] })
                                    }
                                }
                            }
                            Level {
                                Layout.fillWidth: true
                                label: "Light level"
                                value: root.st.rgb ? Math.round(root.st.rgb.brightness * 100 / 255) : 0
                                onMoved: function (v) { root.post("/rgb", { brightness: Math.round(Math.max(5, v) * 255 / 100) }) }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------- apps --
            Item {
                anchors.fill: parent
                visible: root.page === "apps" && !root.picker
                Label {
                    id: appsHint
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: "Tap to open on this screen · hold a running app to close it · swipe up from the bottom edge to come back"
                    color: root.dimColor
                    font.pixelSize: 24 * root.s
                    wrapMode: Text.WordWrap
                }
                Flickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: appsHint.bottom
                    anchors.topMargin: 20 * root.s
                    anchors.bottom: parent.bottom
                    contentHeight: flow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Flow {
                        id: flow
                        width: parent.width
                        spacing: 22 * root.s
                        Repeater {
                            model: root.runningApps
                            AppTile {
                                required property var modelData
                                app: modelData
                                running: true
                                onTapped: root.post("/focus", { id: modelData.id })
                                onHeld: root.post("/close", { id: modelData.id })
                            }
                        }
                        Repeater {
                            model: root.pinnedApps
                            AppTile {
                                required property var modelData
                                app: modelData
                                onTapped: root.post("/launch", { id: modelData.id })
                            }
                        }
                        AppTile {
                            app: ({ name: "Add apps", icon: "list-add-symbolic" })
                            onTapped: {
                                root.request("GET", "/apps", undefined, function (a) { root.allApps = a })
                                root.picker = true
                            }
                        }
                    }
                }
            }

            // app picker: tap to pin/unpin, hold to open right away
            Item {
                anchors.fill: parent
                visible: root.page === "apps" && root.picker
                RowLayout {
                    id: pickerBar
                    width: parent.width
                    Label { text: "Pin apps to the bottom screen"; font.pixelSize: 34 * root.s; font.weight: Font.Bold; Layout.fillWidth: true }
                    Button { Layout.preferredWidth: 180 * root.s; Layout.preferredHeight: 80 * root.s; label: "Done"; onClicked: { root.picker = false; root.refresh() } }
                }
                GridView {
                    anchors.top: pickerBar.bottom
                    anchors.topMargin: 20 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    cellWidth: 222 * root.s
                    cellHeight: 222 * root.s
                    model: root.allApps
                    delegate: AppTile {
                        required property var modelData
                        required property int index
                        app: modelData
                        running: modelData.pinned
                        onTapped: {
                            var list = root.allApps.slice()
                            list[index] = Object.assign({}, modelData, { pinned: !modelData.pinned })
                            root.allApps = list
                            root.post("/pin", { id: modelData.id, pinned: !modelData.pinned })
                        }
                        onHeld: { root.picker = false; root.post("/launch", { id: modelData.id }) }
                    }
                }
            }

            // ---------------------------------------------- trackpad --
            // One finger moves the top screen's pointer, a tap clicks, two
            // fingers scroll; the buttons below can be held while dragging.
            ColumnLayout {
                anchors.fill: parent
                visible: root.page === "pad"
                spacing: 18 * root.s
                Rectangle {
                    id: pad
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 28 * root.s
                    color: root.card
                    border.color: root.line
                    border.width: 2 * root.s
                    property real speed: 1.6
                    property point last
                    property real sx: 0
                    property real sy: 0
                    property real accX: 0
                    property real accY: 0
                    Label {
                        anchors.centerIn: parent
                        text: "Trackpad for the top screen"
                        color: root.line
                        font.pixelSize: 36 * root.s
                    }
                    Timer {
                        // Moves go out at most once a frame.
                        interval: 16
                        repeat: true
                        running: pad.accX !== 0 || pad.accY !== 0 || pad.sx !== 0 || pad.sy !== 0
                        onTriggered: {
                            if (pad.accX !== 0 || pad.accY !== 0) {
                                root.send("/pointer", { dx: Math.round(pad.accX), dy: Math.round(pad.accY) })
                                pad.accX -= Math.round(pad.accX); pad.accY -= Math.round(pad.accY)
                                if (Math.abs(pad.accX) < 1 && Math.abs(pad.accY) < 1) { pad.accX = 0; pad.accY = 0 }
                            }
                            if (Math.abs(pad.sy) >= 1 || Math.abs(pad.sx) >= 1) {
                                root.send("/scroll", { dx: Math.trunc(pad.sx), dy: Math.trunc(pad.sy) })
                                pad.sx -= Math.trunc(pad.sx); pad.sy -= Math.trunc(pad.sy)
                            } else if (!padDrag.active) {
                                pad.sx = 0; pad.sy = 0
                            }
                        }
                    }
                    DragHandler {
                        id: padDrag
                        target: null
                        minimumPointCount: 1
                        maximumPointCount: 2
                        onActiveChanged: if (active) pad.last = centroid.position
                        onCentroidChanged: {
                            if (!active)
                                return
                            var dx = centroid.position.x - pad.last.x
                            var dy = centroid.position.y - pad.last.y
                            pad.last = centroid.position
                            if (centroid.pointCount >= 2) {
                                pad.sx += dx / (40 * root.s)
                                pad.sy += dy / (40 * root.s)
                            } else {
                                // Faster strokes go further.
                                var v = Math.sqrt(dx * dx + dy * dy) / root.s
                                var gain = pad.speed * (1 + Math.min(2, v / 30))
                                pad.accX += dx / root.s * gain
                                pad.accY += dy / root.s * gain
                            }
                        }
                    }
                    TapHandler {
                        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Mouse
                        onTapped: root.send("/button", { button: "left", state: "click" })
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150 * root.s
                    Layout.maximumHeight: 150 * root.s
                    spacing: 18 * root.s
                    Repeater {
                        model: [["left", "Left"], ["middle", "Middle"], ["right", "Right"]]
                        Rectangle {
                            id: mb
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 24 * root.s
                            color: mbp.pressed ? root.cardHi : root.card
                            Label { anchors.centerIn: parent; text: mb.modelData[1]; font.pixelSize: 30 * root.s; font.weight: Font.DemiBold }
                            PointHandler {
                                id: mbp
                                onActiveChanged: root.send("/button", { button: mb.modelData[0], state: active ? "down" : "up" })
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- keyboard --
            // Types on the top screen (whatever has focus there).
            KeyPad {
                anchors.fill: parent
                visible: root.page === "keys"
                s: root.s
                card: root.card
                cardHi: root.cardHi
                accent: root.accent
                textColor: root.textColor
                onTyped: function (kind, value) {
                    root.send("/key", kind === "key" ? { key: value } : { text: value })
                }
            }
        }
    }

    // Bottom screen switched off: black, and the first touch turns it on.
    Rectangle {
        anchors.fill: parent
        visible: root.st.dual !== undefined && root.st.dual !== null && root.st.dual.bottom_on === false
        color: "black"
        z: 10
        TapHandler { onTapped: root.post("/brightness", { bottom_on: true }) }
    }
}
