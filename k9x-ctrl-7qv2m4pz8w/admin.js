// Static admin panel for GitHub Pages. Login is the PIN only.
// The redirect link lives in /index.html and /404.html of the repo; this page rewrites them via the GitHub API.
// The GitHub key the panel writes with is kept (scrambled) in config.json next to this file.
const $ = (id) => document.getElementById(id);
const PIN = "2011";
const REPO = "anonymouslarper1/newlas";
const CONFIG = "k9x-ctrl-7qv2m4pz8w/config.json";
const FILES = ["index.html", "404.html"];
const LOCK = "rd_lock_v1";
const MAX_TRIES = 5, LOCK_MS = 15 * 60 * 1000;

let token = null, branch = null;

// ---------- helpers ----------
const enc = new TextEncoder(), dec = new TextDecoder();
const b64 = (bytes) => btoa(String.fromCharCode(...bytes));
const utf8ToB64 = (s) => b64(enc.encode(s));
const b64ToUtf8 = (s) => dec.decode(Uint8Array.from(atob(s.replace(/\s/g, "")), (c) => c.charCodeAt(0)));
const scramble = (s) => utf8ToB64(s).split("").reverse().join("");
const unscramble = (s) => b64ToUtf8(s.split("").reverse().join(""));
const show = (id) => ["setup", "login", "panel"].forEach((s) => ($(s).hidden = s !== id));
function msg(el, text, type) { el.textContent = text; el.className = "msg " + (type || ""); }
function load(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } }
function save(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }

function lockedFor() {
  const l = load(LOCK) || { n: 0, until: 0 };
  return l.until > Date.now() ? Math.ceil((l.until - Date.now()) / 60000) : 0;
}
function failAttempt() {
  const l = load(LOCK) || { n: 0, until: 0 };
  l.n++;
  if (l.n >= MAX_TRIES) { l.n = 0; l.until = Date.now() + LOCK_MS; }
  save(LOCK, l);
}

// ---------- GitHub API ----------
async function gh(path, opts = {}) {
  const res = await fetch("https://api.github.com/repos/" + REPO + path, {
    ...opts,
    headers: { Authorization: "Bearer " + token, Accept: "application/vnd.github+json", ...(opts.headers || {}) },
    cache: "no-store",
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { const e = new Error(data.message || "GitHub error " + res.status); e.status = res.status; throw e; }
  return data;
}
async function connect() {
  const info = await gh("");
  branch = info.default_branch;
  if (!info.permissions || !info.permissions.push) throw new Error("This key can't write to the site");
}
const getFile = (f) => gh("/contents/" + f + "?ref=" + branch + "&t=" + Date.now());
async function putFile(f, text, message) {
  let sha;
  try { sha = (await getFile(f)).sha; } catch {}
  await gh("/contents/" + f, { method: "PUT", body: JSON.stringify({ message, content: utf8ToB64(text), sha, branch }) });
}

async function savedKey() {
  try {
    const r = await fetch("config.json?t=" + Date.now(), { cache: "no-store" });
    const c = await r.json();
    return c && c.k ? unscramble(c.k) : null;
  } catch { return null; }
}

function pageFor(url) {
  const js = JSON.stringify(url).replace(/</g, "\\u003c");
  const attr = url.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>Redirecting…</title>
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<script>location.replace(${js});</script>
<meta http-equiv="refresh" content="0;url=${attr}">
</head><body><a href="${attr}">Continue</a></body></html>
`;
}
function urlFromPage(html) {
  const m = html.match(/location\.replace\(("(?:[^"\\]|\\.)*")\)/);
  try { return m ? JSON.parse(m[1]) : ""; } catch { return ""; }
}
function validUrl(u) {
  try { const p = new URL(u); return (p.protocol === "http:" || p.protocol === "https:") && u.length <= 2048; }
  catch { return false; }
}

// ---------- UI ----------
function setCurrent(url) { $("current").textContent = url || "(not set)"; $("current").href = url || "#"; $("url").value = url; }

async function openPanel() {
  show("panel");
  try { setCurrent(urlFromPage(b64ToUtf8((await getFile("index.html")).content))); }
  catch (e) { msg($("panelMsg"), e.message, "err"); }
}

$("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = e.submitter, mins = lockedFor();
  if (mins) return msg($("loginMsg"), `Too many attempts. Try again in ${mins} min.`, "err");
  if ($("pin").value !== PIN) {
    failAttempt();
    msg($("loginMsg"), lockedFor() ? "Too many attempts. Locked for 15 min." : "Wrong PIN", "err");
    $("pin").value = "";
    $("pin").classList.add("shake");
    setTimeout(() => $("pin").classList.remove("shake"), 400);
    return;
  }
  save(LOCK, { n: 0, until: 0 });
  $("pin").value = "";
  btn.disabled = true;
  msg($("loginMsg"), "Unlocking…");
  token = await savedKey();
  try {
    if (!token) throw Object.assign(new Error(""), { status: 401 });
    await connect();
    msg($("loginMsg"), "");
    await openPanel();
  } catch (err) {
    msg($("loginMsg"), "");
    if (err.status === 401 || err.status === 403 || err.status === 404) show("setup");
    else msg($("loginMsg"), err.message, "err");
  }
  btn.disabled = false;
});

$("setupForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = e.submitter; btn.disabled = true;
  msg($("setupMsg"), "Connecting…");
  try {
    token = $("token").value.trim();
    await connect();
    await putFile(CONFIG, JSON.stringify({ k: scramble(token) }) + "\n", "Connect admin panel");
    $("token").value = "";
    msg($("setupMsg"), "");
    await openPanel();
  } catch (err) { msg($("setupMsg"), err.message, "err"); }
  btn.disabled = false;
});

$("urlForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const url = $("url").value.trim();
  if (!validUrl(url)) return msg($("panelMsg"), "Enter a valid http(s) link", "err");
  const btn = e.submitter; btn.disabled = true;
  msg($("panelMsg"), "Saving…");
  try {
    for (const f of FILES) await putFile(f, pageFor(url), "Update redirect link");
    setCurrent(url);
    msg($("panelMsg"), "Saved! Live for visitors in about 1 minute.", "ok");
  } catch (err) { msg($("panelMsg"), err.message, "err"); }
  btn.disabled = false;
});

$("logout").addEventListener("click", () => { token = null; location.reload(); });
