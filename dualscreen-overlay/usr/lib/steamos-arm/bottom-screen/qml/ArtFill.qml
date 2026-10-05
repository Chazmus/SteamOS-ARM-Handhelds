// A picture filling its parent with the parent's rounded corners, dimmed
// from the left so text over it stays readable. Empty path: nothing shown.
import QtQuick

Item {
    id: af
    property string path
    property real radius: 0
    property real dim: 0.95           // how dark the left edge gets
    anchors.fill: parent
    readonly property string url: path ? "file://" + path : ""
    visible: url !== "" && cv.ready
    // Canvas does the rounded crop: it draws the same on every renderer.
    Canvas {
        id: cv
        property bool ready: false
        anchors.fill: parent
        renderTarget: Canvas.Image
        property string url: af.url
        onUrlChanged: { ready = false; if (url) { if (isImageLoaded(url)) { ready = true; requestPaint() } else loadImage(url) } }
        Component.onCompleted: if (url) loadImage(url)
        onImageLoaded: { ready = true; requestPaint() }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!url || !isImageLoaded(url)) return
            var im = ctx.createImageData(url)
            var iw = im.width, ih = im.height
            if (!iw || !ih) return
            var k = Math.max(width / iw, height / ih)
            var sw = width / k, sh = height / k
            ctx.save()
            ctx.beginPath()
            ctx.roundedRect(0, 0, width, height, af.radius, af.radius)
            ctx.clip()
            ctx.drawImage(url, (iw - sw) / 2, (ih - sh) / 3, sw, sh, 0, 0, width, height)
            ctx.restore()
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: af.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0.04, 0.06, 0.09, af.dim) }
            GradientStop { position: 0.55; color: Qt.rgba(0.04, 0.06, 0.09, af.dim * 0.72) }
            GradientStop { position: 1; color: Qt.rgba(0.04, 0.06, 0.09, af.dim * 0.25) }
        }
    }
}
