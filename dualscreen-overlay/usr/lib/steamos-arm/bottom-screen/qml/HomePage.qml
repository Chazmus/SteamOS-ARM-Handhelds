// The bottom screen's start page.
//
//   quick toggles   Wi-Fi, Bluetooth, stick lights, bottom screen off
//   open now        every running app: tap to bring it up, ✕ to quit it
//   tools           dashboard, touchpad, keyboard, notes for the game
//   web             Game Guide (follows the game on the top screen), YouTube,
//                   YouTube Music, Steam Chat and your own web apps
//   apps            the desktop apps you added, apps you can get in one tap
//                   (download badge), then New web app, Add apps, Settings
//
// Holding the AYN button or swiping up from the bottom edge always lands here.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: home
    property var running: []
    property var pinned: []
    property var web: []
    property var hub: []               // Emulator Hub apps (from /hub)
    // Apps worth having here that aren't installed yet: one tap gets them,
    // and they pin themselves when done.
    readonly property var suggested: hub.filter(function (a) {
        return a.kind === "app" && !a.installed && a.available && ["vesktop", "signal", "moonlight", "chiaki"].indexOf(a.id) >= 0
    }).slice(0, 3)
    signal open(string page)

    readonly property var st: Ui.st
    readonly property var game: st.game || ({})
    readonly property var tg: st.toggles || ({})
    readonly property var tools: [
        { page: "dash", name: "Dashboard", icon: "speedometer" },
        { page: "pad", name: "Touchpad", icon: "input-touchpad-symbolic" },
        { page: "keys", name: "Keyboard", icon: "input-keyboard-symbolic" },
        { page: "notes", name: "Game Notes", icon: "document-edit" },
        { page: "hub", name: "Get emulators", icon: "download-symbolic" }
    ]
    readonly property var runningIds: running.map(function (a) { return a.id })

    component Toggle: Rectangle {
        id: tgl
        property string label
        property string icon
        property var on                     // true / false / undefined (n/a)
        signal flipped()
        visible: on !== undefined && on !== null
        Layout.fillWidth: true
        Layout.preferredHeight: 92 * Ui.s
        radius: height / 2
        color: on ? Qt.darker(Ui.accent, 1.9) : Ui.button
        border.color: on ? Ui.accent : "transparent"
        border.width: 3 * Ui.s
        RowLayout {
            anchors.centerIn: parent
            spacing: 14 * Ui.s
            Kirigami.Icon { source: tgl.icon; implicitWidth: 40 * Ui.s; implicitHeight: 40 * Ui.s; isMask: true; color: Ui.text }
            Txt { text: tgl.label; font.pixelSize: 26 * Ui.s; font.weight: Font.DemiBold }
        }
        TapHandler { onTapped: tgl.flipped() }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20 * Ui.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 22 * Ui.s

            // ---------------------------------------------------- toggles --
            RowLayout {
                Layout.fillWidth: true
                spacing: 14 * Ui.s
                Toggle {
                    label: "Wi-Fi"; icon: "network-wireless-symbolic"; on: home.tg.wifi
                    onFlipped: Ui.post("/toggle", { name: "wifi", on: !home.tg.wifi })
                }
                Toggle {
                    label: "Bluetooth"; icon: "network-bluetooth-symbolic"; on: home.tg.bluetooth
                    onFlipped: Ui.post("/toggle", { name: "bluetooth", on: !home.tg.bluetooth })
                }
                Toggle {
                    label: "Lights"; icon: "flashlight-on-symbolic"
                    on: home.st.rgb ? home.st.rgb.mode !== "off" : undefined
                    onFlipped: Ui.post("/konkrd/sticks-toggle")
                }
                Toggle {
                    label: "Screen off"; icon: "video-display-symbolic"; on: false
                    onFlipped: Ui.post("/brightness", { bottom_on: false })
                }
            }

            // ------------------------------------------------- open now --
            ColumnLayout {
                Layout.fillWidth: true
                visible: home.running.length > 0
                spacing: 10 * Ui.s
                Txt { text: "Open now"; color: Ui.dim; font.pixelSize: 24 * Ui.s }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110 * Ui.s
                    contentWidth: strip.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    RowLayout {
                        id: strip
                        height: parent.height
                        spacing: 14 * Ui.s
                        Repeater {
                            model: home.running
                            Rectangle {
                                id: chip
                                required property var modelData
                                Layout.preferredWidth: 330 * Ui.s
                                Layout.fillHeight: true
                                radius: 26 * Ui.s
                                color: chipTap.pressed ? Ui.cardHi : Ui.card
                                border.color: Ui.accent
                                border.width: 3 * Ui.s
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18 * Ui.s
                                    anchors.rightMargin: 10 * Ui.s
                                    spacing: 14 * Ui.s
                                    Kirigami.Icon {
                                        source: chip.modelData.icon
                                        fallback: "application-x-executable"
                                        implicitWidth: 56 * Ui.s; implicitHeight: 56 * Ui.s
                                        isMask: String(chip.modelData.icon).endsWith("-symbolic")
                                        color: Ui.text
                                    }
                                    Txt { Layout.fillWidth: true; text: chip.modelData.name; elide: Text.ElideRight; font.pixelSize: 26 * Ui.s }
                                    Rectangle {
                                        Layout.preferredWidth: 72 * Ui.s
                                        Layout.preferredHeight: 72 * Ui.s
                                        radius: width / 2
                                        color: quitTap.pressed ? "#7a2626" : Ui.button
                                        Txt { anchors.centerIn: parent; text: "✕"; font.pixelSize: 30 * Ui.s; font.weight: Font.Bold }
                                        TapHandler { id: quitTap; onTapped: Ui.post("/close", { id: chip.modelData.id }) }
                                    }
                                }
                                TapHandler { id: chipTap; onTapped: Ui.post("/focus", { id: chip.modelData.id }) }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------- tiles (all kinds) --
            Flow {
                Layout.fillWidth: true
                spacing: 18 * Ui.s
                Repeater {
                    model: home.tools
                    Tile {
                        required property var modelData
                        name: modelData.page === "notes" && home.game.name ? "Notes · " + home.game.name : modelData.name
                        icon: modelData.icon
                        mask: modelData.icon.endsWith("-symbolic") || modelData.page === "dash"
                        closable: false
                        onTapped: home.open(modelData.page)
                    }
                }
                Repeater {
                    model: home.web
                    Tile {
                        required property var modelData
                        name: modelData.id === "web:guide" && home.game.name ? "Guide · " + home.game.name : modelData.name
                        icon: modelData.icon
                        running: home.runningIds.indexOf(modelData.id) >= 0
                        closable: false
                        onTapped: Ui.post(running ? "/focus" : "/launch", { id: modelData.id })
                        onHeld: if (modelData.id.indexOf("web:u-") === 0) home.open("newweb")
                    }
                }
                Repeater {
                    model: home.pinned
                    Tile {
                        required property var modelData
                        name: modelData.name
                        icon: modelData.icon
                        closable: false
                        onTapped: Ui.post("/launch", { id: modelData.id })
                        onHeld: home.open("apps")
                    }
                }
                Repeater {
                    model: home.suggested
                    Tile {
                        required property var modelData
                        readonly property var job: modelData.job && modelData.job.state === "running" ? modelData.job : null
                        name: job ? Math.round(job.pct) + "%" : modelData.title
                        icon: "applications-internet"
                        image: modelData.icon || ""
                        download: true
                        progress: job ? job.pct : -1
                        closable: false
                        onTapped: if (!job) Ui.post("/hub/install", { app: modelData.id, pin: true })
                        onHeld: home.open("hub")
                    }
                }
                Tile { name: "Web app"; icon: "list-add-symbolic"; mask: true; closable: false; onTapped: home.open("newweb") }
                Tile { name: "Add apps"; icon: "view-app-grid-symbolic"; mask: true; closable: false; onTapped: home.open("apps") }
                Tile { name: "Settings"; icon: "configure"; mask: true; closable: false; onTapped: home.open("settings") }
            }
            Txt {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Hold the AYN button or swipe up from the bottom edge to come back here"
                color: Ui.dim
                font.pixelSize: 22 * Ui.s
                wrapMode: Text.WordWrap
            }
        }
    }
}
