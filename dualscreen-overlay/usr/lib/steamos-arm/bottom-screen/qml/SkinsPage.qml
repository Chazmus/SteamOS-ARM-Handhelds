// Settings → Dashboard look: every skin, built in and the user's own, drawn
// live with this device's stats. Tap one to use it.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: sp
    property var dash                  // the dashboard page: what the previews draw from
    property var list: []
    property string folder: ""
    property int generation: 0         // bumped to reload previews after editing a skin
    function load() {
        Ui.request("GET", "/skins", undefined, function (r) {
            if (!r) return
            sp.list = r.skins || []
            sp.folder = r.user_folder || ""
        })
    }
    onVisibleChanged: if (visible) load()
    Connections { target: Ui; function onApiChanged() { if (sp.visible) sp.load() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * Ui.s
        RowLayout {
            Layout.fillWidth: true
            Txt { Layout.fillWidth: true; text: "Dashboard look"; font.pixelSize: 36 * Ui.s; font.weight: Font.Bold }
            Btn {
                Layout.preferredWidth: 200 * Ui.s
                Layout.preferredHeight: 72 * Ui.s
                label: "Reload"
                fontSize: 22
                onClicked: { sp.generation++; sp.load() }
            }
        }
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 2
            cellHeight: 420 * Ui.s
            model: sp.list
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool current: (Ui.cfg.skin || "pulse") === modelData.id
                width: grid.cellWidth
                height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10 * Ui.s
                    radius: 28 * Ui.s
                    color: Ui.card
                    border.color: cell.current ? Ui.accent : Ui.line
                    border.width: (cell.current ? 4 : 2) * Ui.s
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18 * Ui.s
                        spacing: 10 * Ui.s
                        // The skin itself, at dashboard width, scaled to fit.
                        Item {
                            id: frame
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            readonly property real full: 1192 * Ui.s
                            Rectangle { anchors.fill: parent; color: Ui.bg; radius: 16 * Ui.s }
                            Loader {
                                id: preview
                                width: frame.full
                                height: item ? item.implicitHeight : 0
                                scale: Math.min(frame.width / frame.full, frame.height / Math.max(1, height))
                                transformOrigin: Item.TopLeft
                                x: (frame.width - width * scale) / 2
                                source: cell.modelData.url + "?" + sp.generation
                                onLoaded: item.dash = sp.dash
                            }
                            Txt {
                                anchors.centerIn: parent
                                width: parent.width - 30 * Ui.s
                                visible: preview.status === Loader.Error
                                text: "This skin doesn't load. Check its Skin.qml."
                                color: Ui.warn
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 22 * Ui.s
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Txt { text: cell.modelData.title + (cell.modelData.builtin ? "" : "  · yours"); font.weight: Font.DemiBold; font.pixelSize: 26 * Ui.s }
                                Txt { Layout.fillWidth: true; text: cell.modelData.about; color: Ui.dim; font.pixelSize: 20 * Ui.s; elide: Text.ElideRight }
                            }
                            Txt { visible: cell.current; text: "In use"; color: Ui.accent; font.pixelSize: 22 * Ui.s; font.weight: Font.Bold }
                        }
                    }
                    TapHandler { onTapped: if (preview.status !== Loader.Error) Ui.setting("skin", cell.modelData.id) }
                }
            }
        }
        Txt {
            Layout.fillWidth: true
            text: "Make your own: a folder with Skin.qml and skin.json in " + sp.folder + " (see the README next to the built-in skins)."
            color: Ui.dim
            font.pixelSize: 20 * Ui.s
            wrapMode: Text.WordWrap
        }
    }
}
