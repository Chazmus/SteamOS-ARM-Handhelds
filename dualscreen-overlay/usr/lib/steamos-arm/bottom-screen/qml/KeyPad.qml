// The on-screen keys, shared by the top screen's keyboard (TopInput.qml) and
// the keyboard that pops up over apps on the bottom screen (Keyboard.qml).
//
// typed(kind, value):
//   "text"   the characters
//   "key"    an X key name (BackSpace, Return, Tab, Escape, Left, Delete...)
//   "combo"  ["ctrl", "c"] and the like, from the modifiers
//   "replace" {back: n, text: "..."}: n backspaces then the text (glide and
//            autocorrect swapping a word)
//
// Three pages: letters, symbols, Fn (Esc, Tab, Home/End, PgUp/PgDn, Del,
// arrows, Copy/Paste/Cut/All/Undo/Redo). Ctrl, Alt, Super and Shift on the
// Fn page stick: lit until the next key, from any page, which then goes out
// as a combo. asciiOnly swaps the symbol page's row of non-ASCII characters
// (a uinput keyboard can't type them) for more punctuation.
//
// Glide typing: a finger that starts on a letter and slides across the keys
// spells a word, decoded by the backend (/glide); the strip above the keys
// offers the next best words, and backspace right after takes the word back.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: kb
    property bool asciiOnly: false
    property bool showHide: false
    property bool glide: Ui.cfg.glide !== false
    property string page: "abc"           // abc, sym, fn
    property bool shift: false
    property bool caps: false
    property var mods: ({})               // sticky ctrl/alt/super/shift
    // Suggestions from the backend: the strip above the keys.
    property var suggestions: []
    property string lastGlide: ""         // backspace right after takes it back
    // The last character this keyboard typed: a glided word gets a space in
    // front of it when it follows a word or punctuation.
    property string lastChar: ""
    signal typed(string kind, var value)
    signal hideRequested()
    spacing: 10 * Ui.s

    readonly property var letters: [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]
    readonly property var symbols: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["-","/",":",";","(",")","&","@","\""],
        asciiOnly ? [".",",","?","!","'","#","%"] : [".",",","?","!","'","€","é"]
    ]
    readonly property var symbols2: [
        ["[","]","{","}","<",">","=","+","*","_"],
        ["\\","|","~","`","^","$"],
        []
    ]
    readonly property bool anyMod: mods.ctrl === true || mods.alt === true || mods.super === true || mods.shift === true

    function modList() {
        var m = []
        for (var k of ["ctrl", "alt", "super", "shift"]) if (mods[k]) m.push(k)
        return m
    }
    function toggleMod(m) {
        var n = Object.assign({}, mods)
        n[m] = !n[m]
        mods = n
    }
    // A key or character, with whatever modifiers are held.
    function emit(kind, value) {
        if (anyMod) {
            typed("combo", modList().concat([kind === "text" ? value.toLowerCase() : value]))
            mods = ({})
            lastChar = ""
            return
        }
        typed(kind, value)
        lastChar = kind === "text" && value.length ? value.charAt(value.length - 1) : ""
    }
    function letter(ch) {
        var out = (shift || caps) ? ch.toUpperCase() : ch
        emit("text", out)
        lastGlide = ""
        if (shift && !caps) shift = false
    }

    component Cap: Rectangle {
        id: cap
        property string label
        property string sub: ""
        property bool active: false
        property real units: 1
        signal hit()
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: units * 100
        radius: 16 * Ui.s
        color: active ? Qt.darker(Ui.accent, 1.9) : (tap.pressed ? Ui.cardHi : Ui.button)
        border.color: active ? Ui.accent : "transparent"
        border.width: 2 * Ui.s
        Txt {
            anchors.centerIn: parent
            text: cap.label
            font.pixelSize: (cap.label.length > 1 ? 26 : 40) * Ui.s
        }
        TapHandler { id: tap; onTapped: cap.hit() }
    }

    // Suggestions (glide alternatives), shown only while there are some.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 64 * Ui.s
        visible: kb.suggestions.length > 0
        spacing: 10 * Ui.s
        Repeater {
            model: kb.suggestions
            Rectangle {
                id: sug
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14 * Ui.s
                color: st.pressed ? Ui.cardHi : "transparent"
                border.color: Ui.line
                border.width: 2 * Ui.s
                Txt { anchors.centerIn: parent; text: sug.modelData.trim(); font.pixelSize: 28 * Ui.s }
                TapHandler {
                    id: st
                    onTapped: {
                        // Swap the glided word for this one.
                        kb.typed("replace", { back: kb.lastGlide.length, text: sug.modelData })
                        kb.lastGlide = sug.modelData
                        kb.suggestions = []
                    }
                }
            }
        }
    }

    // ------------------------------------------------------- letters --
    Item {
        id: letterArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "abc"
        ColumnLayout {
            id: letterRows
            anchors.fill: parent
            spacing: 10 * Ui.s
            Repeater {
                model: 3
                RowLayout {
                    id: krow
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: index === 1 ? 50 * Ui.s : 0
                    Layout.rightMargin: index === 1 ? 50 * Ui.s : 0
                    spacing: 10 * Ui.s
                    Cap {
                        visible: krow.index === 2
                        label: kb.caps ? "⇪" : "⇧"
                        units: 1.5
                        active: kb.shift || kb.caps
                        onHit: {
                            // Tap: next letter upper case. Second tap: caps lock.
                            if (kb.caps) { kb.caps = false; kb.shift = false }
                            else if (kb.shift) { kb.caps = true }
                            else kb.shift = true
                        }
                    }
                    Repeater {
                        model: kb.letters[krow.index]
                        Cap {
                            required property string modelData
                            objectName: "letter_" + modelData
                            label: kb.shift || kb.caps ? modelData.toUpperCase() : modelData
                            onHit: kb.letter(modelData)
                        }
                    }
                    Cap {
                        visible: krow.index === 2
                        label: "⌫"
                        units: 1.5
                        onHit: {
                            if (kb.lastGlide.length && !kb.anyMod) {
                                // Right after a glide: take the whole word back.
                                kb.typed("replace", { back: kb.lastGlide.length, text: "" })
                                kb.lastGlide = ""
                                kb.suggestions = []
                            } else
                                kb.emit("key", "BackSpace")
                        }
                    }
                }
            }
        }
        // Glide: a finger that slides across the letters. Taps fall through
        // to the keys (the handler only takes over once the finger travels).
        DragHandler {
            id: glider
            enabled: kb.glide && !kb.anyMod
            target: null
            dragThreshold: 26 * Ui.s
            property var path: []
            onActiveChanged: {
                if (active) {
                    path = [glider.centroid.pressPosition, glider.centroid.position]
                } else if (path.length > 3) {
                    kb.decode(path)
                    path = []
                }
            }
            onCentroidChanged: if (active) path.push(centroid.position)
        }
    }
    // Key centres for the glide decoder, in this item's coordinates.
    function keyCenters() {
        var out = {}
        function walk(item) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i]
                if (c.objectName && c.objectName.indexOf("letter_") === 0) {
                    var p = c.mapToItem(letterArea, c.width / 2, c.height / 2)
                    out[c.objectName.slice(7)] = [p.x, p.y]
                    kb.keyW = c.width
                }
                walk(c)
            }
        }
        walk(letterRows)
        return out
    }
    property real keyW: 100
    function decode(path) {
        var pts = []
        var step = Math.max(1, Math.floor(path.length / 120))
        for (var i = 0; i < path.length; i += step) pts.push([path[i].x, path[i].y])
        Ui.request("POST", "/glide", { keys: keyCenters(), key_size: keyW, path: pts }, function (r) {
            if (!r || !r.words || !r.words.length)
                return
            var w = r.words[0]
            var upper = kb.shift || kb.caps
            if (upper) w = w.charAt(0).toUpperCase() + w.slice(1)
            if (kb.shift && !kb.caps) kb.shift = false
            var sp = /[A-Za-z0-9.,!?;:)\]"']/.test(kb.lastChar) ? " " : ""
            kb.typed("text", sp + w)
            kb.lastGlide = sp + w
            kb.lastChar = w.charAt(w.length - 1)
            // The next best words, swapped in with the same leading space.
            kb.suggestions = r.words.slice(1, 4).map(function (x) {
                return sp + (upper ? x.charAt(0).toUpperCase() + x.slice(1) : x)
            })
        })
    }

    // ------------------------------------------------------- symbols --
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "sym" || kb.page === "sym2"
        spacing: 10 * Ui.s
        Repeater {
            model: 3
            RowLayout {
                id: srow
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10 * Ui.s
                Cap {
                    visible: srow.index === 2
                    label: kb.page === "sym" ? "#+=" : "123"
                    units: 1.5
                    onHit: kb.page = kb.page === "sym" ? "sym2" : "sym"
                }
                Repeater {
                    model: (kb.page === "sym" ? kb.symbols : kb.symbols2)[srow.index]
                    Cap {
                        required property string modelData
                        label: modelData
                        onHit: { kb.emit("text", modelData); kb.lastGlide = "" }
                    }
                }
                Cap {
                    visible: srow.index === 2
                    label: "⌫"
                    units: 1.5
                    onHit: kb.emit("key", "BackSpace")
                }
            }
        }
    }

    // ------------------------------------------------------------ fn --
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "fn"
        columns: 7
        rowSpacing: 10 * Ui.s
        columnSpacing: 10 * Ui.s
        Repeater {
            model: [
                ["Esc", "key", "Escape"], ["Tab", "key", "Tab"], ["Home", "key", "Home"], ["End", "key", "End"],
                ["PgUp", "key", "Prior"], ["PgDn", "key", "Next"], ["Del", "key", "Delete"],
                ["Copy", "combo", "c"], ["Paste", "combo", "v"], ["Cut", "combo", "x"], ["All", "combo", "a"],
                ["Undo", "combo", "z"], ["Redo", "combo", "y"], ["↑", "key", "Up"],
                ["Ctrl", "mod", "ctrl"], ["Alt", "mod", "alt"], ["Super", "mod", "super"], ["Shift", "mod", "shift"],
                ["←", "key", "Left"], ["↓", "key", "Down"], ["→", "key", "Right"]
            ]
            Cap {
                required property var modelData
                label: modelData[0]
                active: modelData[1] === "mod" && kb.mods[modelData[2]] === true
                onHit: {
                    if (modelData[1] === "mod") kb.toggleMod(modelData[2])
                    else if (modelData[1] === "combo") { kb.typed("combo", ["ctrl", modelData[2]]); kb.mods = ({}) }
                    else kb.emit("key", modelData[2])
                    kb.lastGlide = ""
                }
            }
        }
    }

    // ---------------------------------------------------- bottom row --
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 100
        spacing: 10 * Ui.s
        Cap {
            label: kb.page === "abc" ? "123" : "ABC"
            units: 1.4
            onHit: kb.page = kb.page === "abc" ? "sym" : "abc"
        }
        Cap { label: "Fn"; units: 1.2; active: kb.page === "fn" || kb.anyMod; onHit: kb.page = kb.page === "fn" ? "abc" : "fn" }
        Cap { label: ","; onHit: { kb.emit("text", ","); kb.lastGlide = "" } }
        Cap { label: "space"; units: 4.2; onHit: { kb.emit("text", " "); kb.lastGlide = ""; kb.suggestions = [] } }
        Cap { label: "."; onHit: { kb.emit("text", "."); kb.lastGlide = "" } }
        Cap { label: "Enter"; units: 1.8; onHit: { kb.emit("key", "Return"); kb.lastGlide = ""; kb.suggestions = [] } }
        Cap { label: "▾"; visible: kb.showHide; onHit: kb.hideRequested() }
    }
}
