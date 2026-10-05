// A button with an optional icon above its label. clicked on a tap, held on
// a long press.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: b
    property string label
    property string icon
    property bool active: false
    property real iconSize: 56
    property real fontSize: 28
    property color tint: Ui.accent
    property bool horizontal: false          // icon beside the label instead of above
    signal clicked()
    signal held()
    implicitHeight: 96 * Ui.s
    implicitWidth: 200 * Ui.s
    radius: 22 * Ui.s
    color: tap.pressed ? Ui.cardHi : (active ? Ui.accent : Ui.button)
    Behavior on color { ColorAnimation { duration: 140 } }
    border.color: active ? "transparent" : Ui.cardEdge
    border.width: Math.max(1, 1.5 * Ui.s)
    GridLayout {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 16 * Ui.s)
        flow: b.horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: 14 * Ui.s
        rowSpacing: 8 * Ui.s
        Kirigami.Icon {
            Layout.alignment: Qt.AlignCenter
            visible: b.icon !== ""
            source: b.icon
            implicitWidth: b.iconSize * Ui.s
            implicitHeight: b.iconSize * Ui.s
            color: Ui.text
            isMask: true
        }
        Txt {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: b.width - 16 * Ui.s - (b.horizontal && b.icon !== "" ? (b.iconSize + 14) * Ui.s : 0)
            visible: b.label !== ""
            text: b.label
            elide: Text.ElideRight
            font.pixelSize: b.fontSize * Ui.s
            font.weight: Font.DemiBold
        }
    }
    TapHandler {
        id: tap
        onTapped: b.clicked()
        onLongPressed: b.held()
    }
}
