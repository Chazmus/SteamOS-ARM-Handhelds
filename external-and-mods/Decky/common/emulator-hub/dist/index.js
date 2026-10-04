const manifest = {"name":"Emulator Hub"};
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
const toaster = api.toaster;
const definePlugin = (fn) => (...args) => fn(...args);

const DFL = window.DFL;
const SP_REACT = window.SP_REACT;
const SP_JSX = window.SP_JSX;
const { useEffect, useState, useCallback, useRef } = SP_REACT;
const jsx = SP_JSX.jsx;
const jsxs = SP_JSX.jsxs;

// Decky callable(): arguments are passed positionally to the Python method.
const hub = {
    status: callable("status"),
    jobs: callable("jobs"),
    install: callable("install"),
    update: callable("update"),
    remove: callable("remove"),
    cancel: callable("cancel"),
    starter: callable("starter"),
    checkUpdates: callable("check_updates"),
    updateAll: callable("update_all"),
    library: callable("library"),
    steamPending: callable("steam_pending"),
    reset: callable("reset"),
    addFile: callable("add_file"),
    desktop: callable("desktop"),
    steamMade: callable("steam_made"),
    steamGone: callable("steam_gone"),
    icon: callable("icon"),
};
// Steam's Quick Access page can't show file:// images: the backend hands each
// icon over as a data: URL once, and every list after that reuses it.
const iconCache = new Map();
function AppIcon({ path }) {
    const [src, setSrc] = useState(iconCache.get(path) || "");
    useEffect(() => {
        if (iconCache.has(path)) { setSrc(iconCache.get(path)); return; }
        let live = true;
        hub.icon(path).then((d) => { if (d) iconCache.set(path, d); if (live) setSrc(d || ""); }).catch(() => {});
        return () => { live = false; };
    }, [path]);
    return src
        ? jsx("img", { src, style: { width: "28px", height: "28px", borderRadius: "6px" } })
        : jsx("div", { style: { width: "28px", height: "28px", borderRadius: "6px", background: "rgba(255,255,255,0.08)" } });
}


const CHIP_NAMES = { sm8350: "Snapdragon 888", sm8550: "Snapdragon 8 Gen 2", sm8650: "Snapdragon 8 Gen 3", sm8750: "Snapdragon 8 Elite" };
const SECTIONS = [
    { kind: "emulator", title: "Emulators" },
    { kind: "frontend", title: "Game libraries" },
    { kind: "app", title: "Streaming and apps" },
    { kind: "tool", title: "Desktop tools" },
    { kind: "plugin", title: "Decky plugins" },
];

const row = (child) => jsx(DFL.PanelSectionRow, { children: child });
const small = (text, extra) => jsx("div", { style: Object.assign({ fontSize: "12px", opacity: 0.7, lineHeight: "16px" }, extra || {}), children: text });

// ------------------------------------------------------- Steam library --
// The hub queues a shortcut for everything it installs; Steam's own client
// API adds it here, at once, without restarting Steam. Runs from plugin load,
// so it works with the panel closed (installs started on the bottom screen too).
let syncing = false;
// AddShortcut can succeed and the record after it fail; asking again would
// make a second shortcut, so each app is added at most once per load.
const added = new Set();
async function syncShortcuts() {
    if (syncing || !window.SteamClient || !SteamClient.Apps) return;
    syncing = true;
    try {
        const p = await hub.steamPending();
        for (const s of (p && p.add) || []) {
            if (added.has(s.app)) continue;
            added.add(s.app);
            const appid = Number(await SteamClient.Apps.AddShortcut(s.name, s.exe, s.dir, s.options || ""));
            if (!appid) continue;
            // New shortcuts are named after the file until renamed.
            try { SteamClient.Apps.SetShortcutName(appid, s.name); } catch (e) {}
            try { if (s.options) SteamClient.Apps.SetShortcutLaunchOptions(appid, s.options); } catch (e) {}
            await hub.steamMade(s.app, appid);
            toaster.toast({ title: s.name, body: "Added to your Steam library", duration: 2500 });
        }
        for (const r of (p && p.remove) || []) {
            try { SteamClient.Apps.RemoveShortcut(r.appid); } catch (e) {}
            await hub.steamGone(r.app);
        }
    } catch (e) {
        console.log("Emulator Hub: shortcut sync", e);
    } finally {
        syncing = false;
    }
}

// Non-Steam shortcuts run by their 64-bit game id.
function play(appid) {
    const gameid = ((BigInt(appid >>> 0) << 32n) | 0x02000000n).toString();
    if (SteamClient.Apps.RunGame) SteamClient.Apps.RunGame(gameid, "", -1, 100);
    else SteamClient.URL.ExecuteSteamURL("steam://rungameid/" + gameid);
}

// Toast when a job ends, whoever started it and whether the panel is open.
const seenJobs = {};
async function watchJobs() {
    try {
        const j = await hub.jobs();
        for (const job of (j && j.jobs) || []) {
            const before = seenJobs[job.id];
            seenJobs[job.id] = job.state;
            if (before === "running" && job.state !== "running") {
                const verb = { install: "installed", update: "updated", remove: "removed" }[job.action] || "done";
                if (job.state === "done") toaster.toast({ title: job.app_title || job.app, body: `Ready: ${verb}`, duration: 3000 });
                else if (job.state === "failed") toaster.toast({ title: job.app_title || job.app, body: job.error || "Didn't work", duration: 6000, critical: true });
                if (job.state === "done") syncShortcuts();
            }
        }
    } catch (e) {}
}

// ------------------------------------------------------------- the panel --
function Progress({ job, onCancel }) {
    const pct = Math.round(job.pct || 0);
    const bar = DFL.ProgressBarWithInfo
        ? jsx(DFL.ProgressBarWithInfo, { nProgress: pct, sOperationText: job.stage || "Working", nTransitionSec: 0.4 })
        : small(`${job.stage || "Working"} · ${pct}%`);
    return jsxs("div", { style: { display: "flex", alignItems: "center", gap: "8px", width: "100%" }, children: [
        jsx("div", { style: { flex: 1 }, children: bar }),
        jsx(DFL.DialogButton, { style: { minWidth: "0", width: "56px", padding: "6px" }, onClick: onCancel, children: "✕" }),
    ] });
}

function AppRow({ app, refresh }) {
    const job = app.job && app.job.state === "running" ? app.job : null;
    const act = (fn) => () => fn(app.id).then(refresh);
    const askReset = () => DFL.showModal(jsx(DFL.ConfirmModal, {
        strTitle: `Reset ${app.title}'s settings?`,
        strDescription: "Back to how the hub sets it up: controls, folders, paths. Your old settings file is kept next to it, and games and saves aren't touched.",
        strOKButtonText: "Reset",
        strCancelButtonText: "Keep",
        onOK: () => hub.reset(app.id).then((r) => { toaster.toast({ title: app.title, body: r && r.error ? r.error : "Settings reset" }); refresh(); }),
    }));
    const ask = () => DFL.showModal(jsx(DFL.ConfirmModal, {
        strTitle: `Remove ${app.title}?`,
        strDescription: "Your games, saves and settings stay. Choose “Remove everything” to clear its settings and saves too.",
        strOKButtonText: "Remove",
        strMiddleButtonText: "Remove everything",
        strCancelButtonText: "Keep",
        onOK: () => hub.remove(app.id, false).then(refresh),
        onMiddleButton: () => hub.remove(app.id, true).then(refresh),
    }));
    const desc = [
        app.plays,
        app.label ? `· ${app.label}` : "",
        app.heavy ? "· Heavy for this chip, simpler games run best" : "",
        app.bios ? `· ${app.bios}` : "",
        app.note ? `· ${app.note}` : "",
    ].filter(Boolean).join(" ");
    const state = app.installed
        ? (app.builtin ? "Built in" : app.update ? `Update: ${app.update}` : (app.version ? `Installed · ${app.version}` : "Installed"))
        : app.elsewhere ? "Installed from Discover" : "";
    return jsxs(SP_JSX.Fragment, { children: [
        row(jsx(DFL.Field, {
            label: jsxs("div", { style: { display: "flex", alignItems: "center", gap: "10px" }, children: [
                app.icon ? jsx(AppIcon, { path: app.icon }) : null,
                jsxs("div", { children: [jsx("div", { children: app.title }), state ? small(state, { opacity: 0.9, color: app.update ? "#ffc857" : "#7bd88f" }) : null] }),
            ] }),
            description: desc,
            bottomSeparator: "none",
            childrenLayout: "below",
            children: job ? jsx(Progress, { job, onCancel: () => hub.cancel(job.id).then(refresh) })
                : app.builtin ? null
                : app.installed
                    ? jsxs("div", { style: { display: "flex", gap: "8px" }, children: [
                        app.steam_appid ? jsx(DFL.DialogButton, { onClick: () => play(app.steam_appid), children: "Play" }) : null,
                        app.desktop_only ? jsx(DFL.DialogButton, { onClick: () => hub.desktop(), children: "Desktop Mode" }) : null,
                        app.resettable ? jsx(DFL.DialogButton, { onClick: askReset, children: "Reset" }) : null,
                        app.update ? jsx(DFL.DialogButton, { onClick: act(hub.update), children: "Update" }) : null,
                        jsx(DFL.DialogButton, { onClick: ask, children: "Remove" }),
                    ] })
                    : jsx(DFL.DialogButton, { disabled: !app.available, onClick: act(hub.install), children: app.elsewhere ? "Set up" : app.available ? "Install" : "Not for this device" }),
        })),
    ] });
}

function Content() {
    const [st, setSt] = useState(null);
    const [busy, setBusy] = useState("");
    const [open, setOpen] = useState({ emulator: true, frontend: false, app: false });
    const refresh = useCallback(() => hub.status().then((s) => { if (s && !s.error) setSt(s); }).catch(() => {}), []);
    useEffect(() => {
        refresh();
        const t = setInterval(refresh, 1500);
        return () => clearInterval(t);
    }, [refresh]);

    if (!st) return jsx(DFL.PanelSection, { children: row("Looking at this device…") });
    const dev = st.device || {};
    const starterLeft = st.apps.filter((a) => a.starter && !a.installed && a.available && !(a.job && a.job.state === "running"));
    const running = st.apps.filter((a) => a.job && a.job.state === "running");
    const updates = st.apps.filter((a) => a.update);
    const onSd = (st.sd || []).some((m) => st.library.startsWith(m));

    const work = (label, fn) => () => { setBusy(label); fn().then((r) => {
        if (r && r.error) toaster.toast({ title: "Emulator Hub", body: r.error, critical: true });
        if (r && r.updates) toaster.toast({ title: "Emulator Hub", body: Object.keys(r.updates).length ? `${Object.keys(r.updates).length} update(s) ready` : "Everything is up to date" });
    }).finally(() => { setBusy(""); refresh(); }); };

    return jsxs(SP_JSX.Fragment, { children: [
        jsxs(DFL.PanelSection, { children: [
            row(small(`${dev.model || "This device"} · ${CHIP_NAMES[dev.chip] || dev.chip}${dev.lease ? " · DS and 3DS games use both screens" : ""}`)),
            starterLeft.length ? row(jsx(DFL.ButtonItem, {
                layout: "below",
                onClick: work("starter", hub.starter),
                description: `Picked for this chip: ${starterLeft.map((a) => a.title).join(", ")}`,
                children: busy === "starter" ? "Starting…" : `Install the starter set (${starterLeft.length})`,
            })) : null,
            running.length ? row(small(`${running.length} working: ${running.map((a) => a.title).join(", ")}`)) : null,
            row(jsx(DFL.ButtonItem, {
                layout: "below",
                onClick: updates.length ? work("updates", hub.updateAll) : work("check", hub.checkUpdates),
                children: busy === "check" ? "Checking…" : updates.length ? `Update all (${updates.length})` : "Check for updates",
            })),
        ] }),
        ...SECTIONS.map((sec) => {
            const apps = st.apps.filter((a) => a.kind === sec.kind);
            const have = apps.filter((a) => a.installed).length;
            return jsxs(DFL.PanelSection, { title: `${sec.title}  ·  ${have}/${apps.length}`, children: [
                row(jsx(DFL.ButtonItem, {
                    layout: "below",
                    onClick: () => setOpen(Object.assign({}, open, { [sec.kind]: !open[sec.kind] })),
                    children: open[sec.kind] ? "Hide" : "Show",
                })),
                ...(open[sec.kind] ? apps.map((a) => jsx(AppRow, { app: a, refresh }, a.id)) : []),
            ] });
        }),
        (st.found || []).length ? jsxs(DFL.PanelSection, { title: "Found on this device", children: [
            row(small("AppImages you put in Applications or Downloads yourself. Add one and it shows up in your Steam library.")),
            ...st.found.map((f) => row(jsx(DFL.Field, {
                label: f.name,
                description: f.path,
                childrenLayout: "below",
                bottomSeparator: "none",
                children: f.added ? small("In your Steam library", { color: "#7bd88f" })
                    : jsx(DFL.DialogButton, { onClick: () => hub.addFile(f.path).then(() => { syncShortcuts(); refresh(); }), children: "Add to Steam" }),
            }), f.key)),
        ] }) : null,
        jsxs(DFL.PanelSection, { title: "Game library", children: [
            row(small(st.library)),
            row(jsx(DFL.DropdownItem, {
                label: "Keep games on",
                rgOptions: [{ data: "internal", label: "Internal storage" }].concat((st.sd || []).length ? [{ data: "sd", label: "SD card" }] : []),
                selectedOption: onSd ? "sd" : "internal",
                onChange: (o) => work("library", () => hub.library(o.data))(),
            })),
            row(small("Moving the library brings your games along and points every emulator at the new place. ROMs go in roms/<system>, BIOS files in bios/.")),
        ] }),
    ] });
}

var index = definePlugin(() => {
    syncShortcuts();
    const t1 = setInterval(syncShortcuts, 5000);
    const t2 = setInterval(watchJobs, 3000);
    return {
        name: "Emulator Hub",
        content: jsx(Content, {}),
        icon: jsx("svg", { viewBox: "0 0 24 24", width: "1em", height: "1em", fill: "currentColor", children:
            jsx("path", { d: "M7 6h10a5 5 0 0 1 5 5v2a5 5 0 0 1-8.6 3.5L12 15l-1.4 1.5A5 5 0 0 1 2 13v-2a5 5 0 0 1 5-5zm0 3v1.5H5.5V12H7v1.5h1.5V12H10v-1.5H8.5V9H7zm9.5 1a1 1 0 1 0 0 2 1 1 0 0 0 0-2zm-2 1.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2z" }) }),
        alwaysRender: false,
        onDismount() {
            clearInterval(t1);
            clearInterval(t2);
        },
    };
});

export { index as default };
