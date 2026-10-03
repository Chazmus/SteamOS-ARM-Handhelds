// A labelled reading: value on the right, a bar under it.
import QtQuick

Item {
    id: m
    property string label
    property string value
    property string sub
    property real fraction: 0
    property color tint: Ui.accent
    implicitHeight: 112 * Ui.s
    Txt {
        id: ml
        anchors.left: parent.left
        anchors.top: parent.top
        text: m.label
        color: Ui.dim
        font.pixelSize: 26 * Ui.s
        font.weight: Font.DemiBold
    }
    Txt {
        anchors.left: ml.right
        anchors.leftMargin: 14 * Ui.s
        anchors.right: val.left
        anchors.rightMargin: 10 * Ui.s
        anchors.baseline: ml.baseline
        text: m.sub
        elide: Text.ElideRight
        color: Ui.dim
        font.pixelSize: 22 * Ui.s
    }
    Txt {
        id: val
        anchors.right: parent.right
        anchors.baseline: ml.baseline
        text: m.value
        font.pixelSize: 40 * Ui.s
        font.weight: Font.Bold
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * Ui.s
        height: 14 * Ui.s
        radius: height / 2
        color: Ui.line
        Rectangle {
            height: parent.height
            radius: parent.radius
            color: m.tint
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, m.fraction)))
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
