// A launcher tile: a white glyph on a rounded square whose colour says what
// it is (kind: tool, web, app, add), its name under it. A running app has a
// lit dot under its name; an app that isn't installed yet wears a download
// badge, and a bar while it installs. tapped on a tap, held on a long press.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: t
    property string name
    property string icon
    property string kind: "tool"
    property bool running: false
    property bool closable: false
    property bool mask: icon.endsWith("-symbolic")
    property bool selected: false
    property string image: ""          // an icon file, used over the theme icon
    property bool download: false      // not installed: tap to get it
    property real progress: -1         // 0..100 while installing
    signal tapped()
    signal held()
    signal closeTapped()
    width: 230 * Ui.s
    height: 238 * Ui.s

    readonly property var hues: ({
        tool: [Ui.accent, Qt.darker(Ui.accent, 1.4)],
        web: ["#22c3b4", "#0e8a94"],
        app: ["#8b6cff", "#5a3ad9"],
        add: ["#2a3547", "#1d2735"]
    })
    readonly property var hue: hues[kind] || hues.tool
    // An app's own picture or full-colour icon sits on a quiet face so its
    // colours show; white glyphs get their kind's colour.
    readonly property bool quiet: pic.visible || !mask

    Rectangle {
        id: face
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 172 * Ui.s
        height: width
        radius: width * 0.27
        scale: tap.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        // An app with its own picture sits on a quiet face so its colours
        // show; the rest get their kind's colour.
        gradient: Gradient {
            GradientStop { position: 0; color: Ui.cardHi }
            GradientStop { position: 1; color: Ui.card }
        }
        border.color: t.selected ? Ui.text : "#26ffffff"
        border.width: t.selected ? 4 * Ui.s : Math.max(1, 1.5 * Ui.s)
        // the kind's colour as a glow from below, under the glyph
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !t.quiet
            gradient: Gradient {
                GradientStop { position: 0.35; color: "#00000000" }
                GradientStop { position: 1; color: Qt.rgba(Qt.color(t.hue[0]).r, Qt.color(t.hue[0]).g, Qt.color(t.hue[0]).b, 0.28) }
            }
        }
        // a thin lit edge along the top
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 1
            width: parent.width * 0.6
            height: Math.max(1, 2 * Ui.s)
            radius: height
            color: t.quiet ? "#30ffffff" : Qt.rgba(Qt.color(t.hue[0]).r, Qt.color(t.hue[0]).g, Qt.color(t.hue[0]).b, 0.7)
        }
        Image {
            id: pic
            anchors.centerIn: parent
            width: 104 * Ui.s
            height: width
            source: t.image ? "file://" + t.image : ""
            sourceSize: Qt.size(224, 224)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
            opacity: t.download && t.progress < 0 ? 0.55 : 1
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: t.mask ? 88 * Ui.s : 104 * Ui.s
            height: width
            visible: !pic.visible
            opacity: t.download && t.progress < 0 ? 0.6 : 1
            source: t.icon
            fallback: "application-x-executable"
            isMask: t.mask
            color: t.kind === "add" ? Ui.dim : Qt.lighter(t.hue[0], 1.25)
        }
        Rectangle {
            visible: t.progress >= 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 22 * Ui.s
            height: 10 * Ui.s
            radius: height / 2
            color: "#55000000"
            Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * Math.max(0.04, t.progress / 100)
                color: "#ffffff"
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
        TapHandler {
            id: tap
            onTapped: t.tapped()
            onLongPressed: t.held()
        }
    }
    Row {
        anchors.top: face.bottom
        anchors.topMargin: 12 * Ui.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10 * Ui.s
        Rectangle {
            visible: t.running
            anchors.verticalCenter: parent.verticalCenter
            width: 12 * Ui.s; height: width; radius: width / 2
            color: Ui.accent
        }
        Txt {
            width: Math.min(implicitWidth, t.width - 20 * Ui.s)
            elide: Text.ElideRight
            text: t.name
            color: t.running ? Ui.text : "#d6dee8"
            font.pixelSize: 26 * Ui.s
            font.weight: Font.DemiBold
        }
    }
    // Download badge for an app that isn't here yet.
    Rectangle {
        visible: t.download && t.progress < 0
        x: face.x + face.width - width * 0.7
        y: face.y - height * 0.3
        width: 60 * Ui.s
        height: width
        radius: width / 2
        color: Ui.accent
        border.color: Ui.bg
        border.width: 5 * Ui.s
        Txt { anchors.centerIn: parent; text: "↓"; font.pixelSize: 30 * Ui.s; font.weight: Font.Bold }
    }
    // Close badge (pages that offer it; the launcher closes with a long press).
    Rectangle {
        visible: t.closable
        x: face.x + face.width - width * 0.7
        y: face.y - height * 0.3
        width: 66 * Ui.s
        height: width
        radius: width / 2
        color: closeTap.pressed ? "#7a2626" : "#3a3e4d"
        border.color: Ui.bg
        border.width: 5 * Ui.s
        Txt { anchors.centerIn: parent; text: "✕"; font.pixelSize: 28 * Ui.s; font.weight: Font.Bold }
        TapHandler { id: closeTap; onTapped: t.closeTapped() }
    }
}
