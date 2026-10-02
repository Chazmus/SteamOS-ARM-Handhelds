// The on-screen keys, shared by the top screen's keyboard page (Main.qml)
// and the keyboard that pops up over apps on the bottom screen
// (Keyboard.qml). typed(kind, value): kind "text" with the characters, or
// "key" with an X key name (BackSpace, Return, Tab, Escape, Left, Right).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: kb
    property real s: 1
    property color card: "#161d26"
    property color cardHi: "#223040"
    property color accent: "#1a9fff"
    property color textColor: "#e8eef5"
    property bool shift: false
    property bool sym: false
    signal typed(string kind, string value)
    signal hideRequested()
    property bool showHide: false
    spacing: 10 * s

    readonly property var letters: [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]
    readonly property var symbols: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["-","/",":",";","(",")","&","@","\""],
        [".",",","?","!","'","#","%"]
    ]

    component Cap: Rectangle {
        id: cap
        property string label
        property bool active: false
        property real units: 1
        signal hit()
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: units * 100
        radius: 16 * kb.s
        color: active ? Qt.darker(kb.accent, 1.9) : (tap.pressed ? kb.cardHi : kb.card)
        Text {
            anchors.centerIn: parent
            text: cap.label
            color: kb.textColor
            font.family: "Noto Sans"
            font.pixelSize: (cap.label.length > 1 ? 28 : 40) * kb.s
        }
        TapHandler { id: tap; onTapped: cap.hit() }
    }

    Repeater {
        model: 3
        RowLayout {
            id: krow
            required property int index
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: index === 1 ? 50 * kb.s : 0
            Layout.rightMargin: index === 1 ? 50 * kb.s : 0
            spacing: 10 * kb.s
            Cap {
                visible: krow.index === 2
                label: "⇧"
                units: 1.5
                active: kb.shift
                onHit: kb.shift = !kb.shift
            }
            Repeater {
                model: (kb.sym ? kb.symbols : kb.letters)[krow.index]
                Cap {
                    required property string modelData
                    label: kb.shift && !kb.sym ? modelData.toUpperCase() : modelData
                    onHit: {
                        kb.typed("text", label)
                        kb.shift = false
                    }
                }
            }
            Cap {
                visible: krow.index === 2
                label: "⌫"
                units: 1.5
                onHit: kb.typed("key", "BackSpace")
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10 * kb.s
        Cap { label: kb.sym ? "ABC" : "123"; units: 1.5; active: kb.sym; onHit: kb.sym = !kb.sym }
        Cap { label: "Esc"; units: 1.2; visible: !kb.showHide; onHit: kb.typed("key", "Escape") }
        Cap { label: "Tab"; units: 1.2; onHit: kb.typed("key", "Tab") }
        Cap { label: "space"; units: 4.5; onHit: kb.typed("text", " ") }
        Cap { label: "←"; onHit: kb.typed("key", "Left") }
        Cap { label: "→"; onHit: kb.typed("key", "Right") }
        Cap { label: "Enter"; units: 1.8; onHit: kb.typed("key", "Return") }
        Cap { label: "▾"; visible: kb.showHide; onHit: kb.hideRequested() }
    }
}
