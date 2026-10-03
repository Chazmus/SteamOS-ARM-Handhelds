import QtQuick

Text {
    color: Ui.text
    font.family: Ui.font
    font.pixelSize: 30 * Ui.s
    font.features: { "tnum": 1 }   // digits keep their width: no jitter
}
