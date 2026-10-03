// A home screen tile: icon and name. A running app has an accent ring and a
// close badge in its corner (closable: false for the built-in tiles). An app
// that isn't installed yet wears a download badge, and a bar while it installs.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: t
    property string name
    property string icon
    property bool running: false
    property bool closable: running
    property bool mask: icon.endsWith("-symbolic")
    property bool selected: false
    property string image: ""          // an icon file, used over the theme icon
    property bool download: false      // not installed: tap to get it
    property real progress: -1         // 0..100 while installing
    signal tapped()
    signal held()
    signal closeTapped()
    width: 214 * Ui.s
    height: 236 * Ui.s
    Rectangle {
        id: face
        anchors.top: parent.top
        anchors.topMargin: 18 * Ui.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: 196 * Ui.s
        height: 196 * Ui.s
        radius: 40 * Ui.s
        color: tap.pressed ? Ui.cardHi : Ui.card
        border.color: t.selected || t.running ? Ui.accent : "transparent"
        border.width: 4 * Ui.s
        Image {
            id: pic
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16 * Ui.s
            width: 100 * Ui.s
            height: 100 * Ui.s
            source: t.image ? "file://" + t.image : ""
            sourceSize: Qt.size(200, 200)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
            opacity: t.download && t.progress < 0 ? 0.55 : 1
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16 * Ui.s
            width: 100 * Ui.s
            height: 100 * Ui.s
            visible: !pic.visible
            opacity: t.download && t.progress < 0 ? 0.55 : 1
            source: t.icon
            fallback: "application-x-executable"
            isMask: t.mask
            color: Ui.text
        }
        Txt {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * Ui.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 20 * Ui.s
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: t.name
            font.pixelSize: 24 * Ui.s
        }
        Rectangle {
            visible: t.progress >= 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18 * Ui.s
            anchors.bottomMargin: 54 * Ui.s
            height: 8 * Ui.s
            radius: height / 2
            color: Ui.button
            Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * Math.max(0.04, t.progress / 100)
                color: Ui.accent
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
        TapHandler {
            id: tap
            onTapped: t.tapped()
            onLongPressed: t.held()
        }
    }
    // Download badge for an app that isn't here yet.
    Rectangle {
        visible: t.download && t.progress < 0
        x: face.x + face.width - width * 0.72
        y: face.y - height * 0.28
        width: 64 * Ui.s
        height: 64 * Ui.s
        radius: width / 2
        color: Ui.accent
        border.color: Ui.bg
        border.width: 5 * Ui.s
        Txt { anchors.centerIn: parent; text: "↓"; font.pixelSize: 32 * Ui.s; font.weight: Font.Bold }
    }
    // Close badge, big enough to hit with a thumb.
    Rectangle {
        visible: t.closable
        x: face.x + face.width - width * 0.72
        y: face.y - height * 0.28
        width: 72 * Ui.s
        height: 72 * Ui.s
        radius: width / 2
        color: closeTap.pressed ? "#7a2626" : "#3a3e4d"
        border.color: Ui.bg
        border.width: 5 * Ui.s
        Txt {
            anchors.centerIn: parent
            text: "✕"
            font.pixelSize: 32 * Ui.s
            font.weight: Font.Bold
        }
        TapHandler { id: closeTap; onTapped: t.closeTapped() }
    }
}
