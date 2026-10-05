const manifest = {"name":"Lower Deck"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
}
const callable = api.callable;
const definePlugin = (fn) => (...args) => fn(...args);

const DFL = window.DFL;
const SP_REACT = window.SP_REACT;
const SP_JSX = window.SP_JSX;
const { useEffect, useState, useCallback } = SP_REACT;
const jsx = SP_JSX.jsx;
const jsxs = SP_JSX.jsxs;

const getAll = callable("get_all");
const setTheme = callable("set_theme");
const setLauncher = callable("set_launcher");
const setCompanions = callable("set_companions");
const setCompanionsClose = callable("set_companions_close");

const row = (child) => jsx(DFL.PanelSectionRow, { children: child });
// Trackpad and Keyboard always stay on the home screen (the way to drive the
// top screen from here), so they can move but not hide.
const KEEP = ["page:pad", "page:keys"];

const small = { minWidth: "0", width: "40px", height: "32px", padding: "0", marginLeft: "6px" };

// One home-screen tile: up, down, and shown or not.
function TileRow({ item, first, last, onMove, onShow }) {
    return row(jsx(DFL.Field, {
        label: item.name,
        description: item.hidden ? "Hidden" : undefined,
        bottomSeparator: "none",
        children: jsxs(DFL.Focusable, { style: { display: "flex", alignItems: "center" }, "flow-children": "horizontal", children: [
            jsx(DFL.DialogButton, { style: small, disabled: first, onClick: () => onMove(-1), children: "▲" }),
            jsx(DFL.DialogButton, { style: small, disabled: last, onClick: () => onMove(1), children: "▼" }),
            KEEP.includes(item.id) ? null : jsx(DFL.DialogButton, {
                style: { ...small, width: "56px" }, onClick: () => onShow(item.hidden),
                children: item.hidden ? "Show" : "Hide",
            }),
        ] }),
    }));
}

function Content() {
    const [st, setSt] = useState(null);
    const [game, setGame] = useState(0);
    const [openHome, setOpenHome] = useState(false);
    const refresh = useCallback(async () => {
        const s = await getAll();
        setSt(s);
        if (s && s.up) setGame((g) => g || (s.game && s.game.appid) || 0);
    }, []);
    useEffect(() => { refresh(); }, [refresh]);

    if (!st) return jsx(DFL.PanelSection, { children: row("Loading…") });
    if (!st.up) return jsx(DFL.PanelSection, { children: row(jsx(DFL.Field, {
        label: "The bottom screen isn't running",
        description: "Lower Deck is for two-screen handhelds. On the Thor it comes up with Game Mode.",
    })) });

    const items = st.launcher || [];
    const save = async (list) => {
        setSt({ ...st, launcher: list });
        await setLauncher(list.map((i) => i.id), list.filter((i) => i.hidden).map((i) => i.id));
    };
    const move = (n, d) => {
        const list = items.slice();
        const [it] = list.splice(n, 1);
        list.splice(n + d, 0, it);
        save(list);
    };
    const show = (n, on) => save(items.map((i, k) => (k === n ? { ...i, hidden: !on } : i)));

    const comp = st.companions || {};
    const games = comp.games || [];
    const apps = comp.apps || [];
    const mine = (comp.map || {})[String(game)] || [];
    const toggleApp = async (id, on) => {
        const next = on ? mine.concat([id]) : mine.filter((a) => a !== id);
        setSt({ ...st, companions: { ...comp, map: { ...(comp.map || {}), [String(game)]: next } } });
        await setCompanions(game, next);
    };
    const playing = st.game && st.game.appid ? st.game : null;
    const gameOptions = games.map((g) => ({ data: g.appid, label: g.name }));
    if (playing && !games.some((g) => g.appid === playing.appid))
        gameOptions.unshift({ data: playing.appid, label: playing.name || String(playing.appid) });

    return jsxs(SP_REACT.Fragment, { children: [
        jsxs(DFL.PanelSection, { title: "Look", children: [
            row(jsx(DFL.DropdownItem, {
                label: "Theme",
                rgOptions: (st.skins || []).map((s) => ({ data: s.id, label: s.title })),
                selectedOption: st.skin,
                onChange: async (o) => { setSt({ ...st, skin: o.data }); await setTheme(o.data); },
            })),
        ] }),
        jsxs(DFL.PanelSection, { title: "Home screen", children: [
            row(jsx(DFL.ToggleField, {
                label: "Arrange tiles",
                description: openHome ? undefined : items.filter((i) => i.hidden).length + " hidden",
                checked: openHome,
                onChange: setOpenHome,
            })),
            ...(openHome ? items.map((it, n) => jsx(TileRow, {
                key: it.id, item: it, first: n === 0, last: n === items.length - 1,
                onMove: (d) => move(n, d), onShow: (on) => show(n, on),
            })) : []),
        ] }),
        jsxs(DFL.PanelSection, { title: "With a game", children: [
            row(jsx(DFL.Field, {
                bottomSeparator: "none",
                description: "Apps that open on the bottom screen when the game starts.",
            })),
            gameOptions.length ? row(jsx(DFL.DropdownItem, {
                label: "Game",
                rgOptions: gameOptions,
                selectedOption: game || gameOptions[0].data,
                onChange: (o) => setGame(o.data),
            })) : row(jsx(DFL.Field, { label: "No games found yet" })),
            ...(game || gameOptions.length ? apps.map((a) => row(jsx(DFL.ToggleField, {
                key: a.id,
                label: a.name,
                checked: mine.includes(a.id),
                onChange: (on) => toggleApp(a.id, on),
            }))) : []),
            row(jsx(DFL.ToggleField, {
                label: "Close them when the game ends",
                checked: comp.close !== false,
                onChange: async (on) => { setSt({ ...st, companions: { ...comp, close: on } }); await setCompanionsClose(on); },
            })),
        ] }),
    ] });
}

// Two stacked bars: the two screens.
const Icon = () => jsxs("svg", { width: "1em", height: "1em", viewBox: "0 0 24 24", fill: "currentColor", children: [
    jsx("rect", { x: "4", y: "2", width: "16", height: "9", rx: "2" }),
    jsx("rect", { x: "6", y: "13", width: "12", height: "9", rx: "2", opacity: "0.6" }),
] });

var index = definePlugin(() => ({
    name: "Lower Deck",
    content: jsx(Content, {}),
    icon: jsx(Icon, {}),
    alwaysRender: false,
}));

export { index as default };
