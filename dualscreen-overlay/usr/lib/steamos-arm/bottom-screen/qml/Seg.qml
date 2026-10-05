// One of a few choices, side by side in one pill. options: [[value, label], ...].
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: seg
    property var options: []
    property var current
    property real fontSize: 26
    signal picked(var value)
    implicitHeight: 76 * Ui.s
    radius: height / 2
    color: Ui.button
    RowLayout {
        anchors.fill: parent
        anchors.margins: 6 * Ui.s
        spacing: 6 * Ui.s
        Repeater {
            model: seg.options
            Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: seg.current === modelData[0]
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: height / 2
                color: on ? Ui.accent : (tap.pressed ? Ui.cardHi : "transparent")
                Behavior on color { ColorAnimation { duration: 140 } }
                Txt {
                    anchors.centerIn: parent
                    width: parent.width - 12 * Ui.s
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: opt.modelData[1]
                    color: opt.on ? "#ffffff" : Ui.dim
                    font.pixelSize: seg.fontSize * Ui.s
                    font.weight: opt.on ? Font.Bold : Font.DemiBold
                }
                TapHandler { id: tap; onTapped: seg.picked(opt.modelData[0]) }
            }
        }
    }
}
