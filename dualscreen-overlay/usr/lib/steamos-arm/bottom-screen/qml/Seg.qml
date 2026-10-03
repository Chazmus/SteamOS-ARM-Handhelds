// One of a few choices, side by side. options: [[value, label], ...].
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: seg
    property var options: []
    property var current
    property real fontSize: 26
    signal picked(var value)
    spacing: 12 * Ui.s
    Repeater {
        model: seg.options
        Btn {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 84 * Ui.s
            label: modelData[1]
            fontSize: seg.fontSize
            active: seg.current === modelData[0]
            onClicked: seg.picked(modelData[0])
        }
    }
}
