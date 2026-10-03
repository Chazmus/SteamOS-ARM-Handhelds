// Which apps the home screen shows: tap to pin or unpin, hold to open now.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: pk
    property var apps: []
    signal done()
    function load() { Ui.request("GET", "/apps", undefined, function (a) { if (a) pk.apps = a }) }
    onVisibleChanged: if (visible) load()

    RowLayout {
        id: bar
        width: parent.width
        Txt { text: "Apps on the home screen"; font.pixelSize: 36 * Ui.s; font.weight: Font.Bold; Layout.fillWidth: true }
        Btn {
            Layout.preferredWidth: 180 * Ui.s
            Layout.preferredHeight: 80 * Ui.s
            label: "Done"
            onClicked: pk.done()
        }
    }
    Txt {
        id: hint
        anchors.top: bar.bottom
        anchors.topMargin: 8 * Ui.s
        text: "Tap to add or remove · hold to open now"
        color: Ui.dim
        font.pixelSize: 24 * Ui.s
    }
    GridView {
        anchors.top: hint.bottom
        anchors.topMargin: 16 * Ui.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        cellWidth: 232 * Ui.s
        cellHeight: 250 * Ui.s
        model: pk.apps
        delegate: Tile {
            required property var modelData
            required property int index
            name: modelData.name
            icon: modelData.icon
            closable: false
            selected: modelData.pinned === true
            onTapped: {
                var list = pk.apps.slice()
                list[index] = Object.assign({}, modelData, { pinned: !modelData.pinned })
                pk.apps = list
                Ui.post("/pin", { id: modelData.id, pinned: !modelData.pinned })
            }
            onHeld: { pk.done(); Ui.post("/launch", { id: modelData.id }) }
        }
    }
}
