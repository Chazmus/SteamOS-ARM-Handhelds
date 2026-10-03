// Your own web apps: a name and an address become a home screen tile that
// opens full screen on the bottom screen with its own logins.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: nw
    signal done()
    property string field: "name"         // which box the keys type into
    property string message: ""
    onVisibleChanged: if (visible) { nameBox.text = ""; urlBox.text = ""; field = "name"; message = "" }

    component Box: Rectangle {
        id: box
        property string label
        property alias text: input.text
        property bool current: false
        signal picked()
        Layout.fillWidth: true
        Layout.preferredHeight: 100 * Ui.s
        radius: 20 * Ui.s
        color: Ui.card
        border.color: current ? Ui.accent : Ui.line
        border.width: 3 * Ui.s
        Txt { x: 24 * Ui.s; y: 8 * Ui.s; text: box.label; color: Ui.dim; font.pixelSize: 20 * Ui.s }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 22 * Ui.s
            color: Ui.text
            font.family: Ui.font
            font.pixelSize: 32 * Ui.s
            clip: true
            readOnly: true                 // typed through the keys below
            cursorVisible: box.current
        }
        TapHandler { onTapped: box.picked() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14 * Ui.s
        Txt { text: "New web app"; font.pixelSize: 36 * Ui.s; font.weight: Font.Bold }
        Box { id: nameBox; label: "Name"; current: nw.field === "name"; onPicked: nw.field = "name" }
        Box { id: urlBox; label: "Address (e.g. twitch.tv)"; current: nw.field === "url"; onPicked: nw.field = "url" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 14 * Ui.s
            Txt { Layout.fillWidth: true; text: nw.message; color: Ui.warn; font.pixelSize: 24 * Ui.s }
            Btn { Layout.preferredWidth: 200 * Ui.s; Layout.preferredHeight: 84 * Ui.s; label: "Cancel"; onClicked: nw.done() }
            Btn {
                Layout.preferredWidth: 240 * Ui.s
                Layout.preferredHeight: 84 * Ui.s
                label: "Add to home"
                active: nameBox.text !== "" && urlBox.text !== ""
                onClicked: Ui.request("POST", "/webapp", { name: nameBox.text, url: urlBox.text }, function (r) {
                    if (r && r.ok) nw.done()
                    else nw.message = r && r.error ? "Needs " + r.error : "Couldn't add it"
                })
            }
        }
        // Your web apps, to remove one.
        Flow {
            Layout.fillWidth: true
            spacing: 12 * Ui.s
            Repeater {
                model: Ui.cfg.webapps || []
                Btn {
                    required property var modelData
                    width: 300 * Ui.s
                    height: 72 * Ui.s
                    label: "✕  " + modelData.name
                    fontSize: 24
                    onClicked: Ui.post("/webapp", { remove: modelData.id })
                }
            }
        }
        KeyPad {
            Layout.fillWidth: true
            Layout.fillHeight: true
            swipe: false
            onTyped: function (kind, value) {
                var box = nw.field === "name" ? nameBox : urlBox
                if (kind === "text") box.text += value
                else if (kind === "key" && value === "BackSpace") box.text = box.text.slice(0, -1)
                else if (kind === "key" && (value === "Return" || value === "Tab")) nw.field = nw.field === "name" ? "url" : "name"
            }
        }
    }
}
