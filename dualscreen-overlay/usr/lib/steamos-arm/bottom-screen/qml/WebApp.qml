// A web page as a bottom-screen app: its own window (so the home screen can
// switch to it and close it like any other app) with a touch toolbar.
// Each app keeps its own cookies and logins (its own profile).
//
// qml6 WebApp.qml -- <title> <url> <profile name>
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtWebEngine

Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    width: Screen.width > 0 ? Screen.width : 1240
    height: Screen.height > 0 ? Screen.height : 1080
    color: Ui.bg
    title: args.length > 0 ? args[0] : "Web"

    readonly property var args: {
        var a = Qt.application.arguments
        var i = a.indexOf("--")
        return i >= 0 ? a.slice(i + 1) : []
    }
    readonly property string home: args.length > 1 ? args[1] : "about:blank"
    Binding { target: Ui; property: "s"; value: Math.min(win.width / 1240, win.height / 1080) }

    WebEngineProfile {
        id: profile
        storageName: "steamos-arm-" + (win.args.length > 2 ? win.args[2] : "web")
        offTheRecord: false
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        httpUserAgent: "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        // Toolbar: back, forward, reload, home, zoom, and the page title.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84 * Ui.s
            color: Ui.card
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10 * Ui.s
                spacing: 10 * Ui.s
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: "‹"; fontSize: 40; onClicked: view.goBack() }
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: "›"; fontSize: 40; onClicked: view.goForward() }
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: view.loading ? "✕" : "⟳"; fontSize: 34; onClicked: view.loading ? view.stop() : view.reload() }
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: "⌂"; fontSize: 34; onClicked: view.url = win.home }
                Txt {
                    Layout.fillWidth: true
                    text: view.title || win.title
                    elide: Text.ElideRight
                    color: Ui.dim
                    font.pixelSize: 26 * Ui.s
                }
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: "−"; fontSize: 36; onClicked: view.zoomFactor = Math.max(0.5, view.zoomFactor - 0.1) }
                Btn { Layout.preferredWidth: 90 * Ui.s; Layout.fillHeight: true; label: "+"; fontSize: 36; onClicked: view.zoomFactor = Math.min(2.5, view.zoomFactor + 0.1) }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 4 * Ui.s
                width: parent.width * view.loadProgress / 100
                visible: view.loading
                color: Ui.accent
            }
        }
        WebEngineView {
            id: view
            Layout.fillWidth: true
            Layout.fillHeight: true
            profile: profile
            url: win.home
            // The bottom screen is small and dense: start a bit larger.
            zoomFactor: 1.15
            settings.touchIconsEnabled: true
            settings.fullScreenSupportEnabled: true
            onFullScreenRequested: function (req) { req.accept() }
            // Links that want a new window open here instead.
            onNewWindowRequested: function (req) { view.url = req.requestedUrl }
        }
    }
}
