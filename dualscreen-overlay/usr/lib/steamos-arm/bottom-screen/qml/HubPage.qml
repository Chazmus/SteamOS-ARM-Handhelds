// The Emulator Hub on the bottom screen: the same catalog, jobs and library
// as the Decky panel (steamos-arm-hub does the work), laid out for touch.
// Installs keep going with this page closed; the top screen gets a Steam
// shortcut for each through the Decky panel.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: hp
    property var st: ({ apps: [], device: {}, sd: [] })
    property string kind: "emulator"
    readonly property var shown: (st.apps || []).filter(function (a) { return a.kind === hp.kind })
    readonly property var starterLeft: (st.apps || []).filter(function (a) {
        return a.starter && !a.installed && a.available && !(a.job && a.job.state === "running")
    })
    readonly property var updates: (st.apps || []).filter(function (a) { return a.update })
    readonly property bool onSd: (st.sd || []).some(function (m) { return (st.library || "").indexOf(m) === 0 })
    readonly property var chipNames: ({ sm8350: "Snapdragon 888", sm8550: "Snapdragon 8 Gen 2", sm8650: "Snapdragon 8 Gen 3", sm8750: "Snapdragon 8 Elite" })
    property string note: ""

    function poll() { Ui.request("GET", "/hub", undefined, function (r) { if (r && r.apps) hp.st = r }) }
    function act(what, body) {
        Ui.request("POST", "/hub/" + what, body || {}, function (r) {
            if (r && r.error) hp.note = r.error
            else if (r && r.updates) hp.note = Object.keys(r.updates).length ? Object.keys(r.updates).length + " update(s) ready" : "Everything is up to date"
            hp.poll()
        })
    }
    onVisibleChanged: if (visible) { note = ""; poll() }
    Connections { target: Ui; function onApiChanged() { if (hp.visible) hp.poll() } }
    Timer { interval: 1500; repeat: true; running: hp.visible; onTriggered: hp.poll() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * Ui.s

        RowLayout {
            Layout.fillWidth: true
            spacing: 14 * Ui.s
            Seg {
                Layout.preferredWidth: 640 * Ui.s
                options: [["emulator", "Emulators"], ["frontend", "Libraries"], ["app", "Apps"]]
                current: hp.kind
                fontSize: 24
                onPicked: function (v) { hp.kind = v }
            }
            Item { Layout.fillWidth: true }
            Btn {
                Layout.preferredWidth: 270 * Ui.s
                Layout.preferredHeight: 76 * Ui.s
                fontSize: 22
                label: hp.updates.length ? "Update all (" + hp.updates.length + ")" : "Check for updates"
                active: hp.updates.length > 0
                onClicked: hp.act(hp.updates.length ? "update-all" : "check-updates")
            }
        }
        Txt {
            Layout.fillWidth: true
            text: (hp.st.device.model || "This device") + " · " + (hp.chipNames[hp.st.device.chip] || hp.st.device.chip || "")
                  + (hp.st.device.lease ? " · DS and 3DS games use both screens" : "")
                  + (hp.note ? "   ·   " + hp.note : "")
            color: Ui.dim
            font.pixelSize: 22 * Ui.s
            elide: Text.ElideRight
        }

        // One tap for the set picked for this chip.
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 110 * Ui.s
            visible: hp.starterLeft.length > 0 && hp.kind === "emulator"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 18 * Ui.s
                spacing: 18 * Ui.s
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * Ui.s
                    Txt { text: "Starter set for this device"; font.weight: Font.DemiBold; font.pixelSize: 28 * Ui.s }
                    Txt {
                        Layout.fillWidth: true
                        text: hp.starterLeft.map(function (a) { return a.title }).join(", ")
                        color: Ui.dim
                        font.pixelSize: 22 * Ui.s
                        elide: Text.ElideRight
                    }
                }
                Btn {
                    Layout.preferredWidth: 260 * Ui.s
                    Layout.fillHeight: true
                    label: "Install " + hp.starterLeft.length
                    active: true
                    onClicked: hp.act("starter")
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 2
            cellHeight: 196 * Ui.s
            boundsBehavior: Flickable.StopAtBounds
            model: hp.shown
            delegate: Item {
                id: cell
                required property var modelData
                readonly property var a: modelData
                readonly property var job: a.job && a.job.state === "running" ? a.job : null
                width: grid.cellWidth
                height: grid.cellHeight
                Card {
                    anchors.fill: parent
                    anchors.margins: 8 * Ui.s
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18 * Ui.s
                        spacing: 18 * Ui.s
                        Item {
                            Layout.preferredWidth: 96 * Ui.s
                            Layout.preferredHeight: 96 * Ui.s
                            Layout.alignment: Qt.AlignTop
                            Image {
                                id: pic
                                anchors.fill: parent
                                source: cell.a.icon ? "file://" + cell.a.icon : ""
                                sourceSize: Qt.size(192, 192)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: status === Image.Ready
                            }
                            Kirigami.Icon {
                                anchors.fill: parent
                                visible: !pic.visible
                                source: cell.a.kind === "app" ? "applications-internet" : "applications-games"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4 * Ui.s
                            Txt { Layout.fillWidth: true; text: cell.a.title; font.weight: Font.DemiBold; font.pixelSize: 28 * Ui.s; elide: Text.ElideRight }
                            Txt {
                                Layout.fillWidth: true
                                text: cell.a.plays + (cell.a.label ? " · " + cell.a.label : "")
                                color: Ui.dim
                                font.pixelSize: 21 * Ui.s
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillHeight: true }
                            // Status, or the job's progress.
                            Txt {
                                Layout.fillWidth: true
                                visible: !cell.job
                                text: cell.a.builtin ? "Built in"
                                      : cell.a.update ? "Update ready · " + cell.a.update
                                      : cell.a.installed ? "Installed" + (cell.a.version ? " · " + cell.a.version : "")
                                      : cell.a.elsewhere ? "Installed from Discover · Set up adds it to Steam and the library"
                                      : cell.a.heavy ? "Heavy for this chip" : (cell.a.note || "")
                                color: cell.a.update || (cell.a.heavy && !cell.a.installed) ? "#ffc857" : (cell.a.installed ? Ui.good : Ui.dim)
                                font.pixelSize: 21 * Ui.s
                                elide: Text.ElideRight
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: !!cell.job
                                spacing: 4 * Ui.s
                                Txt {
                                    Layout.fillWidth: true
                                    text: cell.job ? cell.job.stage : ""
                                    color: Ui.dim
                                    font.pixelSize: 19 * Ui.s
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 10 * Ui.s
                                    radius: height / 2
                                    color: Ui.button
                                    Rectangle {
                                        height: parent.height
                                        radius: height / 2
                                        width: parent.width * (cell.job ? cell.job.pct : 0) / 100
                                        color: Ui.accent
                                        Behavior on width { NumberAnimation { duration: 400 } }
                                    }
                                }
                            }
                        }
                        Btn {
                            Layout.preferredWidth: 150 * Ui.s
                            Layout.preferredHeight: 76 * Ui.s
                            Layout.alignment: Qt.AlignVCenter
                            visible: !cell.a.builtin
                            fontSize: 22
                            label: cell.job ? "Stop"
                                   : cell.a.update ? "Update"
                                   : cell.a.installed ? "Remove"
                                   : cell.a.elsewhere ? "Set up"
                                   : cell.a.available ? "Install" : "Not here"
                            active: !cell.a.installed && cell.a.available && !cell.job
                            onClicked: {
                                if (cell.job) hp.act("cancel", { job: cell.job.id })
                                else if (cell.a.update) hp.act("update", { app: cell.a.id })
                                else if (!cell.a.installed && cell.a.available) hp.act("install", { app: cell.a.id })
                                else if (cell.a.installed) hp.note = "Hold Remove to remove " + cell.a.title + " (your games and saves stay)"
                            }
                            onHeld: if (cell.a.installed && !cell.job) hp.act("remove", { app: cell.a.id })
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14 * Ui.s
            Txt {
                Layout.fillWidth: true
                text: "Games go in " + (hp.st.library || "~/Emulation") + "/roms"
                color: Ui.dim
                font.pixelSize: 22 * Ui.s
                elide: Text.ElideMiddle
            }
            Seg {
                Layout.preferredWidth: 420 * Ui.s
                visible: (hp.st.sd || []).length > 0
                options: [["internal", "Internal"], ["sd", "SD card"]]
                current: hp.onSd ? "sd" : "internal"
                fontSize: 22
                onPicked: function (v) { hp.note = "Moving your library…"; hp.act("library", { where: v }) }
            }
        }
    }
}
