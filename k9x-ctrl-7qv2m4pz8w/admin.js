// Static admin panel for GitHub Pages.
// The redirect link lives in /index.html and /404.html of the repo; this page rewrites them via the GitHub API.
// The GitHub token is encrypted with the PIN (AES-GCM, PBKDF2) and stored only in this browser.
const $ = (id) => document.getElementById(id);
const STORE = "rd_admin_v1";
const LOCK = "rd_lock_v1";
const MAX_TRIES = 5, LOCK_MS = 15 * 60 * 1000;
const FILES = ["index.html", "404.html"];

let token = null, repo = null, branch = null;

// ---------- helpers ----------
const enc = new TextEncoder(), dec = new TextDecoder();
const b64 = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)));
const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
const utf8ToB64 = (s) => b64(enc.encode(s));
const b64ToUtf8 = (s) => dec.decode(unb64(s.replace(/\s/g, "")));
const show = (id) => ["setup", "login", "panel"].forEach((s) => ($(s).hidden = s !== id));
function msg(el, text, type) { el.textContent = text; el.className = "msg " + (type || ""); }
function load(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } }
function save(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }

async function sha256Hex(s) {
  const h = await crypto.subtle.digest("SHA-256", enc.encode(s));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function keyFrom(pin, salt) {
  const base = await crypto.subtle.importKey("raw", enc.encode(pin), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "PBKDF2", salt, iterations: 300000, hash: "SHA-256" },
    base, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
}
async function encryptToken(tok, pin) {
  const salt = crypto.getRandomValues(new Uint8Array(16)), iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await keyFrom(pin, salt), enc.encode(tok));
  return { salt: b64(salt), iv: b64(iv), ct: b64(ct) };
}
async function decryptToken(box, pin) {
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(box.iv) },
    await keyFrom(pin, unb64(box.salt)), unb64(box.ct));
  return dec.decode(pt);
}

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
  const res = await fetch("https://api.github.com/repos/" + repo + path, {
    ...opts,
    headers: { Authorization: "Bearer " + token, Accept: "application/vnd.github+json", ...(opts.headers || {}) },
    cache: "no-store",
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || "GitHub error " + res.status);
  return data;
}
async function connect() {
  const info = await gh("");
  branch = info.default_branch;
  if (!info.permissions || !info.permissions.push) throw new Error("Token can't write to this repo");
}
const getFile = (f) => gh("/contents/" + f + "?ref=" + branch + "&t=" + Date.now());

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

const REPO = "anonymouslarper1/newlas";

const stored = load(STORE);
show(stored ? "login" : "setup");

$("setupForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = e.submitter; btn.disabled = true;
  try {
    const pin = $("setupPin").value;
    if ((await sha256Hex(pin)) !== await sha256Hex("2011")) throw new Error("Wrong PIN");
    repo = REPO;
    token = $("token").value.trim();
    await connect();
    save(STORE, { repo, box: await encryptToken(token, pin) });
    $("token").value = ""; $("setupPin").value = "";
    await openPanel();
  } catch (err) { msg($("setupMsg"), err.message, "err"); }
  btn.disabled = false;
});

$("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = e.submitter, mins = lockedFor();
  if (mins) return msg($("loginMsg"), `Too many attempts. Try again in ${mins} min.`, "err");
  btn.disabled = true;
  const s = load(STORE);
  try {
    token = await decryptToken(s.box, $("pin").value);
    repo = REPO;
    save(LOCK, { n: 0, until: 0 });
    $("pin").value = "";
    await connect();
    await openPanel();
  } catch (err) {
    if (!token) {
      failAttempt();
      msg($("loginMsg"), lockedFor() ? "Too many attempts. Locked for 15 min." : "Wrong PIN", "err");
      $("pin").value = "";
      $("pin").classList.add("shake");
      setTimeout(() => $("pin").classList.remove("shake"), 400);
    } else msg($("loginMsg"), err.message, "err");
  }
  btn.disabled = false;
});

$("urlForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const url = $("url").value.trim();
  if (!validUrl(url)) return msg($("panelMsg"), "Enter a valid http(s) link", "err");
  const btn = e.submitter; btn.disabled = true;
  msg($("panelMsg"), "Saving…");
  try {
    for (const f of FILES) {
      let sha;
      try { sha = (await getFile(f)).sha; } catch {}
      await gh("/contents/" + f, {
        method: "PUT",
        body: JSON.stringify({ message: "Update redirect link", content: utf8ToB64(pageFor(url)), sha, branch }),
      });
    }
    setCurrent(url);
    msg($("panelMsg"), "Saved! Live for visitors in about 1 minute.", "ok");
  } catch (err) { msg($("panelMsg"), err.message, "err"); }
  btn.disabled = false;
});

$("logout").addEventListener("click", () => { token = null; location.reload(); });
$("forget").addEventListener("click", () => {
  if (confirm("Remove the saved token from this browser? You'll need to set it up again.")) {
    try { localStorage.removeItem(STORE); } catch {}
    location.reload();
  }
});
