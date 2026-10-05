// A raised panel: a faint top light and edge so cards read as layers.
import QtQuick

Rectangle {
    radius: Ui.radius * Ui.s
    gradient: Gradient {
        GradientStop { position: 0; color: Ui.cardTop }
        GradientStop { position: 1; color: Ui.card }
    }
    border.color: Ui.cardEdge
    border.width: Math.max(1, 1.5 * Ui.s)
}
