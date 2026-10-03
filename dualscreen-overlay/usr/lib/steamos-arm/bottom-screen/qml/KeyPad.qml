// Keys for both keyboards: the one that types on the top screen
// (RemotePad.qml) and the one over bottom-screen apps (Keyboard.qml).
//
// What it sends out, through typed(kind, value):
//   "text"     characters
//   "key"      a key by X name: BackSpace, Return, Tab, Escape, Left, Delete...
//   "combo"    a shortcut, e.g. ["ctrl", "c"]
//   "replace"  {back: n, text: s}: n backspaces, then s (swapping a word)
//
// Pages: letters (QWERTY, QWERTZ or AZERTY, from Settings), numbers and
// symbols (two of them), and Edit: navigation, clipboard shortcuts and the
// modifier latches. A latched Ctrl/Alt/Super/Shift applies to the next key
// from any page and then lets go.
//
// Touch tricks:
//   swipe over the letters   a whole word (the backend's swipetype matches
//                            the trace; the strip offers the runners-up and
//                            backspace right after removes the word)
//   slide along the spacebar moves the cursor, a key per 40 px
//   hold a top-row letter    its digit (q = 1 ... p = 0)
// Finished words (a space or punctuation after letters, a swiped word, a
// picked suggestion) are sent to /learn, so the ones this user types rank
// higher next time.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: kb
    property bool asciiOnly: false
    property bool showHide: false
    property bool swipe: Ui.cfg.swipe !== false
    property string layout: Ui.cfg.layout || "qwerty"
    property string page: "letters"       // letters, numbers, symbols, edit
    property bool shift: false
    property bool capsLock: false
    property var latched: ({})            // ctrl/alt/super/shift held for the next key
    property var suggestions: []
    property string swiped: ""            // the last swiped word, as typed
    property string word: ""              // letters typed since the last break
    property string prev: ""              // last character this keyboard typed
    signal typed(string kind, var value)
    signal hideRequested()
    spacing: 10 * Ui.s

    readonly property var rows: ({
        qwerty: [["q","w","e","r","t","y","u","i","o","p"], ["a","s","d","f","g","h","j","k","l"], ["z","x","c","v","b","n","m"]],
        qwertz: [["q","w","e","r","t","z","u","i","o","p"], ["a","s","d","f","g","h","j","k","l"], ["y","x","c","v","b","n","m"]],
        azerty: [["a","z","e","r","t","y","u","i","o","p"], ["q","s","d","f","g","h","j","k","l","m"], ["w","x","c","v","b","n"]]
    })
    readonly property var letterRows: rows[layout] || rows.qwerty
    readonly property var numberRows: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["-","/",":",";","(",")","&","@","\""],
        asciiOnly ? [".",",","?","!","'","#","%"] : [".",",","?","!","'","€","£"]
    ]
    readonly property var symbolRows: [
        ["[","]","{","}","<",">","=","+","*","_"],
        ["\\","|","~","`","^","$"],
        []
    ]
    readonly property bool anyLatch: Object.keys(latched).some(function (k) { return latched[k] === true })

    // ------------------------------------------------------------ output --
    function latchedList() {
        return ["ctrl", "alt", "super", "shift"].filter(function (k) { return kb.latched[k] === true })
    }
    function toggleLatch(m) {
        var n = Object.assign({}, latched)
        n[m] = !n[m]
        latched = n
    }
    function finishWord() {
        if (word.length >= 2)
            Ui.send("/learn", { word: word })
        word = ""
    }
    function out(kind, value) {
        if (anyLatch) {
            typed("combo", latchedList().concat([kind === "text" ? value.toLowerCase() : value]))
            latched = ({})
            prev = ""
            word = ""
            return
        }
        typed(kind, value)
        if (kind === "text" && value.length) {
            var last = value.charAt(value.length - 1)
            if (/[a-zA-Z]/.test(last))
                word += last.toLowerCase()
            else
                finishWord()
            prev = last
        } else {
            if (value !== "BackSpace") finishWord()
            else word = word.slice(0, -1)
            prev = ""
        }
        swiped = ""
    }
    function tapLetter(ch) {
        out("text", (shift || capsLock) ? ch.toUpperCase() : ch)
        if (shift && !capsLock) shift = false
    }
    function backspace() {
        if (swiped.length && !anyLatch) {
            typed("replace", { back: swiped.length, text: "" })
            swiped = ""
            suggestions = []
            prev = ""
            return
        }
        out("key", "BackSpace")
    }

    // --------------------------------------------------------------- key --
    component Key: Rectangle {
        id: key
        property string label
        property bool lit: false
        property real span: 1
        property string hint: ""          // shown small in the corner (hold)
        signal pressed()
        signal held()
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: span * 100
        radius: 16 * Ui.s
        color: lit ? Qt.darker(Ui.accent, 1.9) : (tap.pressed ? Ui.cardHi : Ui.button)
        border.color: lit ? Ui.accent : "transparent"
        border.width: 2 * Ui.s
        Txt {
            anchors.centerIn: parent
            text: key.label
            font.pixelSize: (key.label.length > 1 ? 26 : 40) * Ui.s
        }
        Txt {
            visible: key.hint !== ""
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8 * Ui.s
            text: key.hint
            color: Ui.dim
            font.pixelSize: 18 * Ui.s
        }
        TapHandler {
            id: tap
            onTapped: key.pressed()
            onLongPressed: key.held()
        }
    }

    // Runners-up for the last swiped word.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 64 * Ui.s
        visible: kb.suggestions.length > 0
        spacing: 10 * Ui.s
        Repeater {
            model: kb.suggestions
            Rectangle {
                id: chip
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14 * Ui.s
                color: chipTap.pressed ? Ui.cardHi : "transparent"
                border.color: Ui.line
                border.width: 2 * Ui.s
                Txt { anchors.centerIn: parent; text: chip.modelData.trim(); font.pixelSize: 28 * Ui.s }
                TapHandler {
                    id: chipTap
                    onTapped: {
                        kb.typed("replace", { back: kb.swiped.length, text: chip.modelData })
                        Ui.send("/learn", { word: chip.modelData.trim() })
                        kb.swiped = chip.modelData
                        kb.suggestions = []
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ letters --
    Item {
        id: letterPage
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "letters"
        ColumnLayout {
            id: letterGrid
            anchors.fill: parent
            spacing: 10 * Ui.s
            Repeater {
                model: 3
                RowLayout {
                    id: lrow
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property var keys: kb.letterRows[index]
                    Layout.leftMargin: index === 1 && keys.length < 10 ? 50 * Ui.s : 0
                    Layout.rightMargin: index === 1 && keys.length < 10 ? 50 * Ui.s : 0
                    spacing: 10 * Ui.s
                    Key {
                        visible: lrow.index === 2
                        label: kb.capsLock ? "⇪" : "⇧"
                        span: 1.5
                        lit: kb.shift || kb.capsLock
                        // Once: next letter upper case. Twice: caps lock.
                        onPressed: {
                            if (kb.capsLock) { kb.capsLock = false; kb.shift = false }
                            else if (kb.shift) kb.capsLock = true
                            else kb.shift = true
                        }
                    }
                    Repeater {
                        model: lrow.keys
                        Key {
                            required property string modelData
                            required property int index
                            objectName: "letter_" + modelData
                            label: kb.shift || kb.capsLock ? modelData.toUpperCase() : modelData
                            hint: lrow.index === 0 ? String((index + 1) % 10) : ""
                            onPressed: kb.tapLetter(modelData)
                            onHeld: if (lrow.index === 0) kb.out("text", String((index + 1) % 10))
                        }
                    }
                    Key {
                        visible: lrow.index === 2
                        label: "⌫"
                        span: 1.5
                        onPressed: kb.backspace()
                    }
                }
            }
        }
        // A finger that travels over the letters is a swipe; a tap still
        // reaches the key under it (this only takes over past the threshold).
        DragHandler {
            id: tracer
            enabled: kb.swipe && !kb.anyLatch
            target: null
            dragThreshold: 26 * Ui.s
            property var trace: []
            onActiveChanged: {
                if (active) {
                    trace = [centroid.pressPosition, centroid.position]
                } else {
                    if (trace.length > 3)
                        kb.matchTrace(trace)
                    trace = []
                }
            }
            onCentroidChanged: if (active) trace.push(centroid.position)
        }
    }
    property real keyWidth: 100
    function letterCentres() {
        var found = {}
        function walk(item) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i]
                if (c.objectName && c.objectName.indexOf("letter_") === 0) {
                    var p = c.mapToItem(letterPage, c.width / 2, c.height / 2)
                    found[c.objectName.slice(7)] = [p.x, p.y]
                    kb.keyWidth = c.width
                }
                walk(c)
            }
        }
        walk(letterGrid)
        return found
    }
    function matchTrace(trace) {
        var pts = []
        var step = Math.max(1, Math.floor(trace.length / 120))
        for (var i = 0; i < trace.length; i += step) pts.push([trace[i].x, trace[i].y])
        Ui.request("POST", "/swipe-words", { keys: letterCentres(), key_width: keyWidth, trace: pts }, function (r) {
            if (!r || !r.words || !r.words.length)
                return
            var upper = kb.shift || kb.capsLock
            function cased(w) { return upper ? w.charAt(0).toUpperCase() + w.slice(1) : w }
            if (kb.shift && !kb.capsLock) kb.shift = false
            // A space first when it follows a word or punctuation.
            var lead = /[A-Za-z0-9.,!?;:)\]"']/.test(kb.prev) ? " " : ""
            kb.finishWord()
            var first = lead + cased(r.words[0])
            kb.typed("text", first)
            Ui.send("/learn", { word: r.words[0] })
            kb.swiped = first
            kb.prev = first.charAt(first.length - 1)
            kb.suggestions = r.words.slice(1, 4).map(function (w) { return lead + cased(w) })
        })
    }

    // ---------------------------------------------------- numbers/symbols --
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "numbers" || kb.page === "symbols"
        spacing: 10 * Ui.s
        Repeater {
            model: 3
            RowLayout {
                id: nrow
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10 * Ui.s
                Key {
                    visible: nrow.index === 2
                    label: kb.page === "numbers" ? "#+=" : "123"
                    span: 1.5
                    onPressed: kb.page = kb.page === "numbers" ? "symbols" : "numbers"
                }
                Repeater {
                    model: (kb.page === "numbers" ? kb.numberRows : kb.symbolRows)[nrow.index]
                    Key {
                        required property string modelData
                        label: modelData
                        onPressed: kb.out("text", modelData)
                    }
                }
                Key {
                    visible: nrow.index === 2
                    label: "⌫"
                    span: 1.5
                    onPressed: kb.backspace()
                }
            }
        }
    }

    // --------------------------------------------------------------- edit --
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        visible: kb.page === "edit"
        columns: 7
        rowSpacing: 10 * Ui.s
        columnSpacing: 10 * Ui.s
        Repeater {
            model: [
                ["Esc", "key", "Escape"], ["Tab", "key", "Tab"], ["Home", "key", "Home"], ["End", "key", "End"],
                ["PgUp", "key", "Prior"], ["PgDn", "key", "Next"], ["Del", "key", "Delete"],
                ["Copy", "combo", "c"], ["Paste", "combo", "v"], ["Cut", "combo", "x"], ["Select all", "combo", "a"],
                ["Undo", "combo", "z"], ["Redo", "combo", "y"], ["↑", "key", "Up"],
                ["Ctrl", "latch", "ctrl"], ["Alt", "latch", "alt"], ["Super", "latch", "super"], ["Shift", "latch", "shift"],
                ["←", "key", "Left"], ["↓", "key", "Down"], ["→", "key", "Right"]
            ]
            Key {
                required property var modelData
                label: modelData[0]
                lit: modelData[1] === "latch" && kb.latched[modelData[2]] === true
                onPressed: {
                    if (modelData[1] === "latch") kb.toggleLatch(modelData[2])
                    else if (modelData[1] === "combo") { kb.typed("combo", ["ctrl", modelData[2]]); kb.latched = ({}) }
                    else kb.out("key", modelData[2])
                }
            }
        }
    }

    // ---------------------------------------------------------- bottom row --
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 100
        spacing: 10 * Ui.s
        Key {
            label: kb.page === "letters" ? "123" : "abc"
            span: 1.4
            onPressed: kb.page = kb.page === "letters" ? "numbers" : "letters"
        }
        Key { label: "Edit"; span: 1.2; lit: kb.page === "edit" || kb.anyLatch; onPressed: kb.page = kb.page === "edit" ? "letters" : "edit" }
        Key { label: ","; onPressed: kb.out("text", ",") }
        // The spacebar: a tap types a space, a slide moves the cursor.
        Key {
            id: space
            label: cursorDrag.active ? "◂  cursor  ▸" : "space"
            span: 4.2
            onPressed: { kb.out("text", " "); kb.suggestions = [] }
            DragHandler {
                id: cursorDrag
                target: null
                yAxis.enabled: false
                dragThreshold: 18 * Ui.s
                property real carry: 0
                property real lastX: 0
                onActiveChanged: { carry = 0; lastX = centroid.position.x; if (active) kb.suggestions = [] }
                onCentroidChanged: {
                    if (!active) return
                    carry += centroid.position.x - lastX
                    lastX = centroid.position.x
                    var stepPx = 40 * Ui.s
                    while (Math.abs(carry) >= stepPx) {
                        kb.out("key", carry > 0 ? "Right" : "Left")
                        carry -= carry > 0 ? stepPx : -stepPx
                    }
                }
            }
        }
        Key { label: "."; onPressed: kb.out("text", ".") }
        Key { label: "Enter"; span: 1.8; onPressed: { kb.out("key", "Return"); kb.suggestions = [] } }
        Key { label: "▾"; visible: kb.showHide; onPressed: kb.hideRequested() }
    }
}
