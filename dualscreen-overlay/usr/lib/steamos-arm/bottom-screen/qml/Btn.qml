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
    signal clicked()
    signal held()
    implicitHeight: 96 * Ui.s
    implicitWidth: 200 * Ui.s
    radius: 20 * Ui.s
    color: tap.pressed ? Ui.cardHi : (active ? Qt.darker(tint, 1.9) : Ui.button)
    border.color: active ? tint : "transparent"
    border.width: 3 * Ui.s
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 16 * Ui.s
        spacing: 8 * Ui.s
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            visible: b.icon !== ""
            source: b.icon
            implicitWidth: b.iconSize * Ui.s
            implicitHeight: b.iconSize * Ui.s
            color: Ui.text
            isMask: true
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
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
