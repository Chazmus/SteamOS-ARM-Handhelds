// Keys for both keyboards: the one that types on the top screen
// (RemotePad.qml) and the one over bottom-screen apps (Keyboard.qml).
//
// What it sends out, through typed(kind, value):
//   "chars"    characters
//   "press"    a key by X name: BackSpace, Return, Tab, Escape, Left, Delete...
//   "chord"    keys held together, e.g. ["ctrl", "c"]
//   "retype"   {erase: n, chars: s}: rub out n characters, then type s
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
// Tapped words (Settings, both on by default):
//   autocorrect   a finished word that is a clear typo is swapped for the
//                 word meant; backspace straight after, or the ↶ chip, puts
//                 yours back and remembers it. Endings for the word being
//                 typed fill the strip meanwhile.
//   capitals      two spaces make a full stop, and a new sentence starts
//                 with shift on
// Kept words (finished and not corrected, swiped, picked) go to /learn, so
// the ones this user types rank higher next time.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: kb
    property bool plainKeys: false
    property bool hideKey: false
    property bool swipe: Ui.cfg.swipe !== false
    property string layout: Ui.cfg.layout || "qwerty"
    property string page: "letters"       // letters, numbers, symbols, edit
    property bool shift: false
    property bool capsLock: false
    property var latched: ({})            // ctrl/alt/super/shift held for the next key
    property var suggestions: []
    property string strip: ""             // what the strip offers: swipe, ends, undo
    property bool autocorrect: Ui.cfg.autocorrect !== false
    property bool capitals: Ui.cfg.capitals !== false
    property var mended: null             // the last autocorrection, while it can be undone
    property int serial: 0                // counts what was typed, so late answers are dropped
    property string before: ""            // the character before prev
    property bool atStart: false          // the next word starts a sentence
    property bool wordAtStart: false
    property bool autoShift: false        // shift was turned on by a sentence end
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
        plainKeys ? [".",",","?","!","'","#","%"] : [".",",","?","!","'","€","£"]
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
    // Learning waits for autocorrect's verdict, so a typo is never learned.
    function finishWord() {
        if (word.length >= 2 && !autocorrect)
            Ui.send("/learn", { word: word })
        word = ""
    }
    function showStrip(mode, list) {
        strip = mode
        suggestions = list
    }
    function out(kind, value) {
        serial++
        if (anyLatch) {
            typed("chord", latchedList().concat([kind === "chars" ? value.toLowerCase() : value]))
            latched = ({})
            prev = ""
            word = ""
            return
        }
        mended = null
        // Two spaces after a word: a full stop and one space.
        if (kind === "chars" && value === " " && prev === " " && /[A-Za-z0-9]/.test(before) && capitals) {
            typed("retype", { erase: 1, chars: ". " })
            prev = " "
            before = "."
            sentenceEnd()
            return
        }
        typed(kind, value)
        if (kind === "chars" && value.length) {
            var last = value.charAt(value.length - 1)
            if (/[a-zA-Z]/.test(last)) {
                if (word === "") wordAtStart = atStart
                word += last
                atStart = false
                if (autocorrect && word.length >= 2 && swiped === "") askEnds(word, serial)
            } else {
                var w = word
                finishWord()
                if (strip === "ends") showStrip("", [])
                if (autocorrect && w !== "" && /[ .,!?;:]/.test(last))
                    askFix(w, last, wordAtStart, serial)
                else if (strip !== "swipe")
                    showStrip("", [])
                if (last === " " && /[.!?]/.test(prev))
                    sentenceEnd()
                else if (last !== " ")
                    atStart = false
            }
            before = prev
            prev = last
        } else {
            if (value !== "BackSpace") { finishWord(); atStart = value === "Return" && capitals }
            else word = word.slice(0, -1)
            prev = ""
            before = ""
            showStrip("", [])
        }
        swiped = ""
    }
    // A sentence just ended: the next letter is a capital.
    function sentenceEnd() {
        atStart = true
        if (capitals && !capsLock && !shift) { shift = true; autoShift = true }
    }
    function askEnds(prefix, at) {
        Ui.request("POST", "/word-ends", { prefix: prefix }, function (r) {
            if (r && kb.serial === at && kb.word === prefix)
                kb.showStrip("ends", r.words || [])
        })
    }
    function askFix(w, sep, start, at) {
        Ui.request("POST", "/word-fix", { word: w, layout: kb.layout, start: start }, function (r) {
            if (!r)
                return
            if (!r.fix || r.fix === w) {
                Ui.send("/learn", { word: w })
                return
            }
            if (kb.serial !== at)     // more was typed meanwhile: leave it be
                return
            kb.typed("retype", { erase: w.length + sep.length, chars: r.fix + sep })
            Ui.send("/learn", { word: r.fix })
            kb.mended = { from: w, to: r.fix, sep: sep, at: at }
            kb.showStrip("undo", [w])
        })
    }
    // Put back the word autocorrect replaced, and remember it as meant.
    function unmend(keepSep) {
        var m = mended
        typed("retype", { erase: m.to.length + m.sep.length, chars: m.from + (keepSep ? m.sep : "") })
        Ui.send("/learn", { word: m.from, sure: true })
        mended = null
        word = keepSep ? "" : m.from
        prev = keepSep ? m.sep : m.from.charAt(m.from.length - 1)
        showStrip("", [])
        serial++
    }
    function tapLetter(ch) {
        var autoUp = autoShift
        out("chars", (shift || capsLock) ? ch.toUpperCase() : ch)
        if (shift && !capsLock) { shift = false; autoShift = false }
        if (autoUp) autoShift = false
    }
    function backspace() {
        if (mended && mended.at === serial && !anyLatch) {
            unmend(false)
            return
        }
        if (swiped.length && !anyLatch) {
            typed("retype", { erase: swiped.length, chars: "" })
            swiped = ""
            showStrip("", [])
            prev = ""
            return
        }
        if (autoShift) { shift = false; autoShift = false }
        out("press", "BackSpace")
    }
    function pick(choice) {
        if (strip === "undo") {
            unmend(true)
        } else if (strip === "ends") {
            typed("retype", { erase: word.length, chars: choice + " " })
            Ui.send("/learn", { word: choice })
            word = ""
            before = choice.charAt(choice.length - 1)
            prev = " "
            atStart = false
            serial++
            showStrip("", [])
        } else {
            typed("retype", { erase: swiped.length, chars: choice })
            Ui.send("/learn", { word: choice.trim() })
            swiped = choice
            showStrip("", [])
        }
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

    // The strip: runners-up for a swiped word, endings for the word being
    // typed, or the word autocorrect just replaced (tap to keep yours).
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
                Txt {
                    anchors.centerIn: parent
                    text: kb.strip === "undo" ? "↶  " + chip.modelData : chip.modelData.trim()
                    color: kb.strip === "undo" ? Ui.dim : Ui.text
                    font.pixelSize: 28 * Ui.s
                }
                TapHandler {
                    id: chipTap
                    onTapped: {
                        kb.pick(chip.modelData)
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
                            onHeld: if (lrow.index === 0) kb.out("chars", String((index + 1) % 10))
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
            kb.typed("chars", first)
            Ui.send("/learn", { word: r.words[0] })
            kb.swiped = first
            kb.prev = first.charAt(first.length - 1)
            kb.showStrip("swipe", r.words.slice(1, 4).map(function (w) { return lead + cased(w) }))
            kb.serial++
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
                        onPressed: kb.out("chars", modelData)
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
                ["Esc", "press", "Escape"], ["Tab", "press", "Tab"], ["Find", "chord", ["ctrl", "f"]],
                ["Save", "chord", ["ctrl", "s"]], ["Close tab", "chord", ["ctrl", "w"]],
                ["Undo", "chord", ["ctrl", "z"]], ["Redo", "chord", ["ctrl", "shift", "z"]],
                ["Copy", "chord", ["ctrl", "c"]], ["Cut", "chord", ["ctrl", "x"]], ["Paste", "chord", ["ctrl", "v"]],
                ["Select all", "chord", ["ctrl", "a"]], ["◂ Word", "chord", ["ctrl", "Left"]],
                ["Word ▸", "chord", ["ctrl", "Right"]], ["⌦", "press", "Delete"],
                ["Ctrl", "latch", "ctrl"], ["Alt", "latch", "alt"], ["Super", "latch", "super"], ["Shift", "latch", "shift"],
                ["Line start", "press", "Home"], ["↑", "press", "Up"], ["Line end", "press", "End"],
                ["Page ▲", "press", "Prior"], ["Page ▼", "press", "Next"], ["⌫ Word", "chord", ["ctrl", "BackSpace"]],
                ["Menu", "press", "Menu"], ["←", "press", "Left"], ["↓", "press", "Down"], ["→", "press", "Right"]
            ]
            Key {
                required property var modelData
                label: modelData[0]
                lit: modelData[1] === "latch" && kb.latched[modelData[2]] === true
                onPressed: {
                    if (modelData[1] === "latch") kb.toggleLatch(modelData[2])
                    else if (modelData[1] === "chord") { kb.typed("chord", modelData[2]); kb.latched = ({}) }
                    else kb.out("press", modelData[2])
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
        Key { label: ","; onPressed: kb.out("chars", ",") }
        // The spacebar: a tap types a space, a slide moves the cursor.
        Key {
            id: space
            label: cursorDrag.active ? "◂  cursor  ▸" : "space"
            span: 4.2
            onPressed: kb.out("chars", " ")
            DragHandler {
                id: cursorDrag
                target: null
                yAxis.enabled: false
                dragThreshold: 18 * Ui.s
                property real carry: 0
                property real lastX: 0
                onActiveChanged: { carry = 0; lastX = centroid.position.x; if (active) kb.showStrip("", []) }
                onCentroidChanged: {
                    if (!active) return
                    carry += centroid.position.x - lastX
                    lastX = centroid.position.x
                    var stepPx = 40 * Ui.s
                    while (Math.abs(carry) >= stepPx) {
                        kb.out("press", carry > 0 ? "Right" : "Left")
                        carry -= carry > 0 ? stepPx : -stepPx
                    }
                }
            }
        }
        Key { label: "."; onPressed: kb.out("chars", ".") }
        Key { label: "Enter"; span: 1.8; onPressed: kb.out("press", "Return") }
        Key { label: "▾"; visible: kb.hideKey; onPressed: kb.hideRequested() }
    }
}
