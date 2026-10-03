// Notes kept per game: whatever is in front on the top screen gets its own
// page (codes, a route, where you left off). Saved a moment after typing
// stops, and when the page goes away. With no game running: general notes.
import QtQuick
import QtQuick.Layouts

Item {
    id: np
    property int appid: -1
    property string gameName: ""
    property bool dirty: false
    function load() {
        Ui.request("GET", "/notes", undefined, function (n) {
            if (!n) return
            np.appid = n.appid
            np.gameName = n.name || ""
            area.text = n.text || ""
            np.dirty = false
        })
    }
    function save() {
        if (!dirty || appid < 0) return
        Ui.post("/notes", { appid: appid, text: area.text })
        dirty = false
    }
    onVisibleChanged: visible ? load() : save()
    Connections { target: Ui; function onApiChanged() { if (np.visible) np.load() } }
    Timer { id: autosave; interval: 1500; onTriggered: np.save() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14 * Ui.s
        RowLayout {
            Layout.fillWidth: true
            Txt {
                Layout.fillWidth: true
                text: np.gameName ? np.gameName : "General notes"
                font.pixelSize: 36 * Ui.s
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Txt { text: np.dirty ? "editing…" : "saved"; color: Ui.dim; font.pixelSize: 24 * Ui.s }
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Flickable {
                id: fl
                anchors.fill: parent
                anchors.margins: 24 * Ui.s
                contentHeight: area.contentHeight
                clip: true
                TextEdit {
                    id: area
                    width: fl.width
                    wrapMode: TextEdit.Wrap
                    color: Ui.text
                    font.family: Ui.font
                    font.pixelSize: 30 * Ui.s
                    selectionColor: Ui.accent
                    onTextChanged: { np.dirty = true; autosave.restart() }
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y + cursorRectangle.height > fl.contentY + fl.height)
                            fl.contentY = cursorRectangle.y + cursorRectangle.height - fl.height
                    }
                }
            }
        }
        // Our own keys: TextEdit takes them directly, no round trip.
        KeyPad {
            Layout.fillWidth: true
            Layout.fillHeight: false         // its keys would claim it all
            Layout.preferredHeight: 440 * Ui.s
            onTyped: function (kind, value) {
                area.forceActiveFocus()
                if (kind === "chars") area.insert(area.cursorPosition, value)
                else if (kind === "retype") {
                    var at = Math.max(0, area.cursorPosition - value.erase)
                    area.remove(at, area.cursorPosition)
                    area.insert(at, value.chars)
                } else if (kind === "press") {
                    var p = area.cursorPosition
                    if (value === "BackSpace" && p > 0) area.remove(p - 1, p)
                    else if (value === "Delete") area.remove(p, Math.min(area.length, p + 1))
                    else if (value === "Return") area.insert(p, "\n")
                    else if (value === "Tab") area.insert(p, "\t")
                    else if (value === "Left") area.cursorPosition = Math.max(0, p - 1)
                    else if (value === "Right") area.cursorPosition = Math.min(area.length, p + 1)
                    else if (value === "Home") area.cursorPosition = 0
                    else if (value === "End") area.cursorPosition = area.length
                } else if (kind === "chord") {
                    var k = value[value.length - 1]
                    if (k === "a") area.selectAll()
                    else if (k === "c") area.copy()
                    else if (k === "v") area.paste()
                    else if (k === "x") area.cut()
                    else if (k === "z") area.undo()
                    else if (k === "y") area.redo()
                }
            }
        }
    }
}
