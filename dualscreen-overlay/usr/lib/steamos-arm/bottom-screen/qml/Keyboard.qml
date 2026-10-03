// Keyboard for apps on the bottom screen. Backend: ../dashboard.
//
// Its own full-screen, see-through window (and process). The backend makes
// it a gamescope overlay (STEAM_OVERLAY) and, while shown, sets
// STEAM_INPUT_FOCUS=2 on it, as Steam's own keyboard does: it takes the
// touches, and X keyboard focus stays on the app underneath, which the
// backend types into (XTest). It opens when a text field in a bottom-screen
// app gets focus (AT-SPI) and sits at the top when the field is in the lower
// half. Tapping outside the keys closes it. Only this screen's apps are
// affected; the top screen never sees these keys.
import QtQuick
import QtQuick.Window

Window {
    id: win
    title: "SteamOS Bottom Keyboard"
    visible: true
    visibility: Window.FullScreen
    width: Screen.width > 0 ? Screen.width : 1240
    height: Screen.height > 0 ? Screen.height : 1080
    color: "transparent"

    property bool shown: false
    property bool atTop: false
    property bool polling: false
    Binding { target: Ui; property: "s"; value: Math.min(win.width / 1240, win.height / 1080) }

    Component.onCompleted: {
        var args = Qt.application.arguments
        var si = args.indexOf("--shot")
        if (si >= 0) {
            var wh = args[si + 2].split("x")
            win.visibility = Window.Windowed
            win.width = parseInt(wh[0])
            win.height = parseInt(wh[1])
            win.color = "#202a36"            // stands in for the app underneath
            shown = true
            shotTimer.file = args[si + 1]
            shotTimer.start()
        }
        Ui.loadApi(args[args.length - 1])
    }
    Timer {
        id: shotTimer
        property string file
        interval: 2000
        onTriggered: win.contentItem.grabToImage(function (r) { r.saveToFile(shotTimer.file); Qt.quit() })
    }

    // Shown/hidden and where, from the backend's focus watcher.
    Timer {
        interval: 120
        running: shotTimer.file === ""
        repeat: true
        onTriggered: {
            if (win.polling)
                return
            win.polling = true
            Ui.request("GET", "/keyboard", undefined, function (k) {
                win.polling = false
                if (!k)
                    return
                win.atTop = k.top === true
                if (k.visible === true && !win.shown)
                    keys.suggestions = []
                win.shown = k.visible === true
            })
        }
    }

    // Outside the keys (the part of the screen the panel doesn't cover):
    // close, so the next tap reaches the app.
    MouseArea {
        enabled: win.shown
        anchors.left: parent.left
        anchors.right: parent.right
        y: win.atTop ? panel.height : 0
        height: parent.height - panel.height
        onClicked: { win.shown = false; Ui.send("/keyboard", { visible: false }) }
    }

    Rectangle {
        id: panel
        visible: win.shown
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.5
        y: win.atTop ? 0 : parent.height - height
        color: Ui.bg
        KeyPad {
            id: keys
            anchors.fill: parent
            anchors.margins: 14 * Ui.s
            showHide: true
            onTyped: function (kind, value) {
                if (kind === "combo") Ui.send("/type", { combo: value })
                else if (kind === "replace") Ui.send("/type", { replace: value })
                else if (kind === "key") Ui.send("/type", { key: value })
                else Ui.send("/type", { text: value })
            }
            onHideRequested: { win.shown = false; Ui.send("/keyboard", { visible: false }) }
        }
    }
}
