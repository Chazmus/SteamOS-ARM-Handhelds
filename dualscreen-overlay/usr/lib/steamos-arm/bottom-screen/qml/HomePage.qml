// Home screen: the built-in tools, then the apps. A running app's tile
// brings it forward and has a close badge; tapping a pinned one starts it on
// this screen. Swiping up from the bottom edge or holding the AYN button
// comes back here from any app.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: home
    property var running: []
    property var pinned: []
    signal open(string page)

    readonly property var tools: [
        { page: "dash", name: "Dashboard", icon: "speedometer" },
        { page: "pad", name: "Trackpad", icon: "input-touchpad-symbolic" },
        { page: "keys", name: "Keyboard", icon: "input-keyboard-symbolic" }
    ]

    Txt {
        id: hint
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        horizontalAlignment: Text.AlignHCenter
        text: "Swipe up from the bottom edge or hold the AYN button to come back here"
        color: Ui.dim
        font.pixelSize: 22 * Ui.s
        wrapMode: Text.WordWrap
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: hint.top
        anchors.bottomMargin: 12 * Ui.s
        contentHeight: flow.implicitHeight + 30 * Ui.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Flow {
            id: flow
            y: 14 * Ui.s
            width: parent.width
            spacing: 18 * Ui.s
            Repeater {
                model: home.tools
                Tile {
                    required property var modelData
                    name: modelData.name
                    icon: modelData.icon
                    mask: true
                    onTapped: home.open(modelData.page)
                }
            }
            Repeater {
                model: home.running
                Tile {
                    required property var modelData
                    name: modelData.name
                    icon: modelData.icon
                    running: true
                    onTapped: Ui.post("/focus", { id: modelData.id })
                    onCloseTapped: Ui.post("/close", { id: modelData.id })
                }
            }
            Repeater {
                model: home.pinned
                Tile {
                    required property var modelData
                    name: modelData.name
                    icon: modelData.icon
                    onTapped: Ui.post("/launch", { id: modelData.id })
                    onHeld: home.open("apps")
                }
            }
            Tile {
                name: "Add apps"
                icon: "list-add-symbolic"
                mask: true
                onTapped: home.open("apps")
            }
            Tile {
                name: "Settings"
                icon: "configure"
                mask: true
                onTapped: home.open("settings")
            }
        }
    }
}
