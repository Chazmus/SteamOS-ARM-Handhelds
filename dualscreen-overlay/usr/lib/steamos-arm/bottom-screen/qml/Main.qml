// Bottom screen dashboard UI. Backend: ../dashboard (HTTP on 127.0.0.1).
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Window {
    id: root
    title: "SteamOS Bottom Screen"
    visible: true
    visibility: Window.FullScreen
    color: bg

    readonly property color bg: "#0e141b"
    readonly property color card: "#1a232e"
    readonly property color cardHi: "#243140"
    readonly property color accent: "#1a9fff"
    readonly property color textColor: "#dfe6ee"
    readonly property color dimColor: "#8b97a4"
    readonly property real u: Math.max(8, Math.min(width, height) / 60)   // base unit

    Rectangle { anchors.fill: parent; color: bg }

    property string api: ""
    property string token: ""
    property var st: ({})
    property var allApps: []
    property bool picker: false

    // ---------------------------------------------------------- backend --
    function request(method, path, body, done) {
        if (!api)
            return
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE && done && x.status === 200)
                done(JSON.parse(x.responseText))
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
    function refresh() { request("GET", "/state", undefined, function (s) { st = s }) }
    function post(path, body) { request("POST", path, body === undefined ? {} : body, function () { refresh() }) }

    // qml6 Main.qml -- [--shot out.png WxH] api-file: save a picture of the
    // UI and quit (layout checks without the device).
    property string shotFile: ""
    Timer {
        id: shotTimer
        interval: 2500
        onTriggered: root.contentItem.grabToImage(function (r) { r.saveToFile(shotFile); Qt.quit() })
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
            shotTimer.start()
        }
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState === XMLHttpRequest.DONE) {
                var cfg = JSON.parse(x.responseText)
                api = cfg.url
                token = cfg.token
                refresh()
            }
        }
        x.open("GET", "file://" + args[args.length - 1])
        x.send()
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: refresh() }

    // ------------------------------------------------------- components --
    component Card: Rectangle {
        radius: u
        color: card
    }

    component BigButton: Rectangle {
        id: bb
        property string label
        property string icon
        property bool active: false
        signal clicked()
        signal held()
        radius: u
        color: mouse.pressed ? cardHi : (active ? Qt.darker(accent, 1.6) : card)
        border.color: active ? accent : "transparent"
        border.width: 2
        ColumnLayout {
            anchors.centerIn: parent
            spacing: u * 0.5
            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                source: bb.icon
                visible: bb.icon !== ""
                implicitWidth: u * 4
                implicitHeight: u * 4
                color: textColor
                isMask: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: bb.label
                color: textColor
                font.pixelSize: u * 1.6
                font.bold: true
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            onClicked: bb.clicked()
            onPressAndHold: bb.held()
        }
    }

    component LevelSlider: Item {
        id: ls
        property string label
        property int value: 0
        signal moved(int v)
        implicitHeight: u * 5
        Text {
            id: lbl
            text: ls.label
            color: dimColor
            font.pixelSize: u * 1.4
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: u * 12
            elide: Text.ElideRight
        }
        Rectangle {
            id: track
            anchors.left: lbl.right
            anchors.right: pct.left
            anchors.rightMargin: u
            anchors.verticalCenter: parent.verticalCenter
            height: u * 1.2
            radius: height / 2
            color: cardHi
            Rectangle {
                width: parent.width * Math.max(0, ls.value) / 100
                height: parent.height
                radius: parent.radius
                color: accent
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -u * 1.5
                preventStealing: true
                function set(mx) {
                    var v = Math.round(Math.max(0, Math.min(1, (mx - u * 1.5) / track.width)) * 100)
                    ls.value = v
                    throttle.pending = v
                    if (!throttle.running) throttle.start()
                }
                onPressed: function (e) { set(e.x) }
                onPositionChanged: function (e) { set(e.x) }
                onReleased: { throttle.stop(); ls.moved(throttle.pending) }
            }
            Timer {
                id: throttle
                property int pending: 0
                interval: 120
                onTriggered: ls.moved(pending)
            }
        }
        Text {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: u * 4
            horizontalAlignment: Text.AlignRight
            text: ls.value >= 0 ? ls.value + "%" : "–"
            color: textColor
            font.pixelSize: u * 1.4
        }
    }

    component AppTile: Rectangle {
        id: at
        property var app
        property bool running: false
        signal tapped()
        signal held()
        width: u * 9
        height: u * 9
        radius: u
        color: mouseA.pressed ? cardHi : card
        border.color: running ? accent : "transparent"
        border.width: 2
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: u
            width: u * 4.5
            height: u * 4.5
            source: at.app ? at.app.icon : ""
            fallback: "application-x-executable"
            isMask: source.toString().endsWith("-symbolic")
            color: textColor
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: u * 0.6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - u
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: at.app ? at.app.name : ""
            color: textColor
            font.pixelSize: u * 1.2
        }
        MouseArea {
            id: mouseA
            anchors.fill: parent
            onClicked: at.tapped()
            onPressAndHold: at.held()
        }
    }

    // ------------------------------------------------------------ layout --
    Flickable {
        anchors.fill: parent
        anchors.margins: u * 1.5
        contentHeight: main.implicitHeight
        clip: true
        visible: !picker

        ColumnLayout {
            id: main
            width: parent.width
            spacing: u * 1.5

            // status
            RowLayout {
                Layout.fillWidth: true
                spacing: u * 2
                Text { text: st.time || ""; color: textColor; font.pixelSize: u * 2.4; font.bold: true }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: st.show_stats === false ? [] : [
                        st.temps ? "CPU " + st.temps.cpu + "°" : "",
                        st.temps ? "GPU " + st.temps.gpu + "°" : "",
                        st.gpu_mhz ? st.gpu_mhz + " MHz" : "",
                        st.fan >= 0 ? "Fan " + st.fan + "%" : ""
                    ]
                    Text { text: modelData; visible: modelData !== ""; color: dimColor; font.pixelSize: u * 1.5 }
                }
                Text {
                    text: st.battery && st.battery.percent >= 0
                          ? (st.battery.status === "Charging" ? "⚡ " : "") + st.battery.percent + "%" : ""
                    color: st.battery && st.battery.percent < 15 ? "#ff6b6b" : textColor
                    font.pixelSize: u * 1.8
                    font.bold: true
                }
            }

            // Steam
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: u
                BigButton { Layout.fillWidth: true; Layout.preferredHeight: u * 9; label: "Steam"; icon: "go-home-symbolic"; onClicked: post("/steam/steam") }
                BigButton { Layout.fillWidth: true; Layout.preferredHeight: u * 9; label: "Quick Access"; icon: "view-more-horizontal-symbolic"; onClicked: post("/steam/qam") }
                BigButton { Layout.fillWidth: true; Layout.preferredHeight: u * 9; label: "Keyboard"; icon: "input-keyboard-virtual-symbolic"; onClicked: post("/steam/keyboard") }
                BigButton { Layout.fillWidth: true; Layout.preferredHeight: u * 9; label: "Screenshot"; icon: "camera-photo-symbolic"; onClicked: post("/steam/screenshot") }
            }

            // performance
            Card {
                Layout.fillWidth: true
                implicitHeight: perf.implicitHeight + u * 2
                RowLayout {
                    id: perf
                    anchors.fill: parent
                    anchors.margins: u
                    spacing: u
                    Repeater {
                        model: [["silent", "Silent"], ["balanced", "Balanced"], ["turbo", "Turbo"]]
                        BigButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: u * 6
                            label: modelData[1]
                            active: st.profile === modelData[0]
                            onClicked: post("/konkrd/profile-" + modelData[0])
                        }
                    }
                    BigButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: u * 6
                        label: "Fan boost"
                        active: st.fan_boost === true
                        onClicked: post("/konkrd/fan-boost")
                    }
                }
            }

            // levels
            Card {
                Layout.fillWidth: true
                implicitHeight: levels.implicitHeight + u * 2
                ColumnLayout {
                    id: levels
                    anchors.fill: parent
                    anchors.margins: u
                    Repeater {
                        model: st.backlights || []
                        LevelSlider {
                            Layout.fillWidth: true
                            label: modelData.label
                            value: modelData.percent
                            onMoved: function (v) { post("/brightness", { id: modelData.id, percent: v }) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        LevelSlider {
                            Layout.fillWidth: true
                            label: st.volume && st.volume.muted ? "Volume (muted)" : "Volume"
                            value: st.volume ? st.volume.percent : 0
                            onMoved: function (v) { post("/volume", { percent: v }) }
                        }
                        BigButton {
                            Layout.preferredWidth: u * 8
                            Layout.preferredHeight: u * 5
                            label: st.volume && st.volume.muted ? "Unmute" : "Mute"
                            onClicked: post("/volume", { mute: "toggle" })
                        }
                    }
                }
            }

            // apps
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Apps"; color: textColor; font.pixelSize: u * 1.8; font.bold: true }
                Text {
                    text: "tap to open · hold a running app to close it · swipe up from the bottom edge to come back"
                    color: dimColor
                    font.pixelSize: u * 1.1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: u
                Repeater {
                    model: st.running || []
                    AppTile {
                        app: modelData
                        running: true
                        onTapped: post("/focus", { id: modelData.id })
                        onHeld: post("/close", { id: modelData.id })
                    }
                }
                Repeater {
                    model: (st.pinned || []).filter(function (p) {
                        return !(st.running || []).some(function (r) { return r.id === p.id })
                    })
                    AppTile {
                        app: modelData
                        onTapped: post("/launch", { id: modelData.id })
                    }
                }
                AppTile {
                    app: ({ name: "Add apps", icon: "list-add-symbolic" })
                    onTapped: {
                        request("GET", "/apps", undefined, function (a) { allApps = a })
                        picker = true
                    }
                }
            }
        }
    }

    // app picker: tap to pin/unpin, hold to open right away
    Item {
        anchors.fill: parent
        anchors.margins: u * 1.5
        visible: picker
        RowLayout {
            id: pickerBar
            width: parent.width
            Text { text: "Pin apps to the bottom screen"; color: textColor; font.pixelSize: u * 2; font.bold: true; Layout.fillWidth: true }
            BigButton { Layout.preferredWidth: u * 10; Layout.preferredHeight: u * 5; label: "Done"; onClicked: { picker = false; refresh() } }
        }
        GridView {
            anchors.top: pickerBar.bottom
            anchors.topMargin: u
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            cellWidth: u * 10
            cellHeight: u * 10
            model: allApps
            delegate: AppTile {
                app: modelData
                running: modelData.pinned
                onTapped: {
                    var list = allApps.slice()
                    list[index] = Object.assign({}, modelData, { pinned: !modelData.pinned })
                    allApps = list
                    post("/pin", { id: modelData.id, pinned: !modelData.pinned })
                }
                onHeld: { picker = false; post("/launch", { id: modelData.id }) }
            }
        }
    }
}
