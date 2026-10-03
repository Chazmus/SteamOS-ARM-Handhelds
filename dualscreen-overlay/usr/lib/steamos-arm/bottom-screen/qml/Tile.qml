// A home screen tile: icon and name. A running app has an accent ring and a
// close badge in its corner (closable: false for the built-in tiles).
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
        Kirigami.Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -16 * Ui.s
            width: 100 * Ui.s
            height: 100 * Ui.s
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
        TapHandler {
            id: tap
            onTapped: t.tapped()
            onLongPressed: t.held()
        }
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
