// Bottom screen settings, saved by the backend in
// ~/.config/steamos-arm/bottom-screen.json.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Flickable {
    id: sp
    contentHeight: col.implicitHeight + 20 * Ui.s
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property var cfg: Ui.cfg
    signal open(string page)

    component Row: Card {
        id: row
        property string title
        property string help
        default property alias content: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(slot.implicitHeight, texts.implicitHeight) + 40 * Ui.s
        ColumnLayout {
            id: texts
            anchors.left: parent.left
            anchors.leftMargin: 28 * Ui.s
            anchors.right: slot.left
            anchors.rightMargin: 20 * Ui.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * Ui.s
            Txt { text: row.title; font.weight: Font.DemiBold }
            Txt {
                Layout.fillWidth: true
                visible: row.help !== ""
                text: row.help
                color: Ui.dim
                font.pixelSize: 22 * Ui.s
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 20 * Ui.s
            anchors.verticalCenter: parent.verticalCenter
            width: 520 * Ui.s
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 16 * Ui.s
        Txt { text: "Settings"; font.pixelSize: 40 * Ui.s; font.weight: Font.Bold }

        Row {
            title: "Theme"
            help: "Pulse, Aura, Gauges, Pure Black or your own."
            Btn {
                Layout.fillWidth: true
                Layout.preferredHeight: 84 * Ui.s
                label: "Choose…"
                fontSize: 24
                onClicked: sp.open("skins")
            }
        }
        Row {
            title: "Dashboard steps back"
            help: "After this long without a touch, a dashboard opened with the AYN button goes back to the app it was opened over."
            Seg {
                Layout.fillWidth: true
                options: [[0, "Never"], [10, "10 s"], [30, "30 s"], [60, "1 min"]]
                current: sp.cfg.dash_idle_s !== undefined ? sp.cfg.dash_idle_s : 0
                fontSize: 24
                onPicked: function (v) { Ui.setting("dash_idle_s", v) }
            }
        }
        Row {
            title: "Trackpad speed"
            Seg {
                Layout.fillWidth: true
                options: [[1.0, "Slow"], [1.6, "Normal"], [2.4, "Fast"], [3.4, "Faster"]]
                current: sp.cfg.pad_speed !== undefined ? sp.cfg.pad_speed : 1.6
                fontSize: 24
                onPicked: function (v) { Ui.setting("pad_speed", v) }
            }
        }
        Row {
            title: "Natural scrolling"
            help: "Two fingers move the page the way they slide, like a phone."
            Seg {
                Layout.fillWidth: true
                options: [[false, "Off"], [true, "On"]]
                current: sp.cfg.pad_natural === true
                fontSize: 24
                onPicked: function (v) { Ui.setting("pad_natural", v) }
            }
        }
        Row {
            title: "Swipe typing"
            help: "Slide a finger across the letters to type a word."
            Seg {
                Layout.fillWidth: true
                options: [[true, "On"], [false, "Off"]]
                current: sp.cfg.swipe !== false
                fontSize: 24
                onPicked: function (v) { Ui.setting("swipe", v) }
            }
        }
        Row {
            title: "Capitals and full stops"
            help: "A new sentence starts with a capital, and two spaces end one with a full stop."
            Seg {
                Layout.fillWidth: true
                options: [[true, "On"], [false, "Off"]]
                current: sp.cfg.capitals !== false
                fontSize: 24
                onPicked: function (v) { Ui.setting("capitals", v) }
            }
        }
        Row {
            title: "Keyboard layout"
            help: "For the bottom screen's own keys. Swipe typing follows it."
            Seg {
                Layout.fillWidth: true
                options: [["qwerty", "QWERTY"], ["qwertz", "QWERTZ"], ["azerty", "AZERTY"]]
                current: sp.cfg.layout || "qwerty"
                fontSize: 24
                onPicked: function (v) { Ui.setting("layout", v) }
            }
        }
        Row {
            title: "Scroll coasting"
            help: "A quick two-finger flick keeps the page moving for a moment after you let go."
            Seg {
                Layout.fillWidth: true
                options: [[true, "On"], [false, "Off"]]
                current: sp.cfg.momentum !== false
                fontSize: 24
                onPicked: function (v) { Ui.setting("momentum", v) }
            }
        }
        Row {
            title: "Autocorrect"
            help: "Fixes clear typos as each word ends, and suggests endings while you type. Tap ↶ or backspace to keep your word; it won't be changed again."
            Seg {
                Layout.fillWidth: true
                options: [[true, "On"], [false, "Off"]]
                current: sp.cfg.autocorrect !== false
                fontSize: 24
                onPicked: function (v) { Ui.setting("autocorrect", v) }
            }
        }
        Row {
            title: "Bottom screen"
            help: "Off until you touch it again. Turning it off in Desktop Mode works too."
            Btn {
                Layout.fillWidth: true
                Layout.preferredHeight: 84 * Ui.s
                label: "Turn off"
                fontSize: 24
                onClicked: Ui.post("/brightness", { bottom_on: false })
            }
        }
    }
}
