// Shared by every page of the bottom screen UI: theme, the canvas scale and
// the backend (../dashboard, HTTP on 127.0.0.1 with a per-run token).
//
// Everything is laid out on a 1240x1080 canvas (the AYN Thor's bottom panel)
// and multiplied by s, so text and touch targets keep their size relative to
// the screen on the Pocket DS's 1024x768 too.
pragma Singleton
import QtQuick

QtObject {
    id: ui
    property real s: 1

    // Slate with one accent (Steam's blue), and a colour per reading so a
    // glance tells them apart: CPU sky, GPU violet, power amber, memory mint.
    readonly property color bg: theme.bg || "#080c12"
    readonly property color bgTop: theme.bgTop || "#0f1622"
    readonly property color card: theme.card || "#121a25"
    readonly property color cardTop: theme.cardTop || "#172131"
    readonly property color cardEdge: theme.cardEdge || "#1fffffff"
    readonly property color cardHi: theme.cardHi || "#24344a"
    // Buttons sit on cards too, so they get their own shade.
    readonly property color button: theme.button || "#1a2433"
    readonly property color line: theme.line || "#243042"
    readonly property color accent: theme.accent || "#1a9fff"
    readonly property color accentSoft: theme.accentSoft || "#331a9fff"
    readonly property color text: theme.text || "#eef3f8"
    readonly property color dim: theme.dim || "#8a98aa"
    readonly property color faint: theme.faint || "#5b6878"
    readonly property color warn: "#ff6b6b"
    readonly property color good: "#40d080"
    readonly property color cpu: "#38bdf8"
    readonly property color gpu: "#a78bfa"
    readonly property color power: "#fbbf24"
    readonly property color mem: "#34d399"
    readonly property color hot: "#fb7185"
    readonly property real radius: 28
    readonly property string font: "Noto Sans"

    property string api: ""
    property string token: ""
    // Last /state reply (stats are kept while an app covers the dashboard).
    property var st: ({})
    readonly property var cfg: st.config || ({})
    // A skin can bring its own colours (skin.json "colors"); they apply to
    // every page, not only the dashboard. shotColors stands in for screenshots.
    property var shotColors: null
    // An app just started from the launcher ({name, icon, image}): Main
    // covers the screen with it until its window is up.
    property var launching: null
    readonly property var theme: shotColors || cfg.skin_colors || ({})

    function request(method, path, body, done) {
        if (!api)
            return
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE || !done)
                return
            var obj = null
            if (x.status === 200) {
                try { obj = JSON.parse(x.responseText) } catch (e) {}
            }
            done(obj)
        }
        x.open(method, api + path)
        x.setRequestHeader("X-Token", token)
        if (body !== undefined) {
            x.setRequestHeader("Content-Type", "application/json")
            x.send(JSON.stringify(body))
        } else {
            x.send()
        }
    }
    signal changed()            // a POST went through: refresh soon
    function post(path, body) {
        request("POST", path, body === undefined ? {} : body, function () { ui.changed() })
    }
    // Fire and forget (trackpad moves, keys): no refresh per event.
    function send(path, body) { request("POST", path, body === undefined ? {} : body) }
    function setting(key, value) {
        var b = {}
        b[key] = value
        post("/settings", b)
    }

    // Reads the API address + token from the private file the backend wrote.
    function loadApi(file, done) {
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return
            try {
                var c = JSON.parse(x.responseText)
                token = c.token          // first: setting api wakes pages that call it
                api = c.url
            } catch (e) {}
            if (done)
                done()
        }
        x.open("GET", "file://" + file)
        x.send()
    }

    function num(v, digits) { return v === undefined || v === null ? "–" : Number(v).toFixed(digits || 0) }
    function rate(bytes) {
        if (bytes === undefined || bytes === null) return "–"
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s"
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB/s"
        return bytes + " B/s"
    }
}
