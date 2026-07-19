// Smoke test - run: node test/smoke.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { JSDOM, VirtualConsole } from "jsdom";

const root = path.resolve(fileURLToPath(import.meta.url), "../..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");

// The app is the LAST <script> block (block 1 is vendored Leaflet).
const blocks = html.split("<script>").slice(1).map(b => b.split("</script>")[0]);
const js = blocks[blocks.length - 1];
if (!js || !js.includes("PacketMap") && !js.includes("VERSION")) {
  throw new Error("Could not extract app <script> block from index.html");
}

// ── Test 1: syntax ────────────────────────────────────────────────────────
try {
  new Function(js);
  console.log("PASS  1/5  syntax check (app script)");
} catch (e) {
  throw new Error(`FAIL  1/5  syntax error: ${e.message}`);
}

// ── Test 2: getElementById coverage ──────────────────────────────────────
const ids = [
  ...[...js.matchAll(/getElementById\(["']([^"']+)["']\)/g)].map(m => m[1]),
  ...[...js.matchAll(/\$\(["']([^"']+)["']\)/g)].map(m => m[1]),
];
const present = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]));
const missing = [...new Set(ids)].filter(id => !present.has(id));
if (missing.length) {
  throw new Error(`FAIL  2/5  getElementById calls with no matching id="": ${missing.join(", ")}`);
}
console.log(`PASS  2/5  getElementById coverage (${new Set(ids).size} IDs checked)`);

// ── Test 3: boot in jsdom ────────────────────────────────────────────────
const vc = new VirtualConsole();
const errors = [];
vc.on("error", msg => errors.push(String(msg)));
vc.on("jsdomError", e => errors.push(e.message));

const dom = new JSDOM(html, {
  url: "https://cdburgess75.github.io/PacketMap/",
  runScripts: "dangerously",
  pretendToBeVisual: true,
  virtualConsole: vc,
  beforeParse(w) {
    const store = (() => {
      let s = {};
      return {
        getItem:    k      => k in s ? s[k] : null,
        setItem:    (k, v) => { s[k] = String(v); },
        removeItem: k      => { delete s[k]; },
        clear:      ()     => { s = {}; },
        get length() { return Object.keys(s).length; },
        key:        i      => Object.keys(s)[i] ?? null,
      };
    })();
    Object.defineProperty(w, "localStorage", { value: store, configurable: true });
    w.matchMedia = () => ({ matches: false, addEventListener: () => {}, removeEventListener: () => {} });
    w.fetch = () => Promise.resolve({ ok: true, text: () => Promise.resolve(""), json: () => Promise.resolve({}) });
    // jsdom ships a real WebSocket; stub it so boot's auto-connect can't dial out during tests.
    w.WebSocket = function () { this.binaryType = ""; this.readyState = 0; this.send = () => {}; this.close = () => { this.readyState = 3; }; };
    // no geolocation / indexedDB: the app must degrade gracefully
  },
});
await new Promise(r => setTimeout(r, 400));
const fatal = errors.filter(e => !/canvas|not implemented|Could not load img/i.test(e));
if (fatal.length) {
  throw new Error(`FAIL  3/5  jsdom boot errors:\n${fatal.join("\n")}`);
}
const doc = dom.window.document;
if (!doc.getElementById("hdrVer").textContent.startsWith("v")) {
  throw new Error("FAIL  3/5  app did not boot (version not rendered)");
}
console.log("PASS  3/5  boots in jsdom without errors");

// ── Test 4: parser sanity on real packets ────────────────────────────────
const w = dom.window;
const checks = [
  // uncompressed position with PHG
  ["N5YHM-1>APN391,TANGI-1*,WIDE3-2,qAO,KF5VOI:!3028.26N/09002.60W#PHG5130 Abita Springs, LA",
    p => p.type === "pos" && Math.abs(p.lat - 30.471) < 0.001 && Math.abs(p.lng + 90.0433) < 0.001 && p.symC === "#"],
  // weather station
  ["KE5JZM-1>APN000,TCPIP*,qAC,T2PANAMA:@170005z3002.62N/09041.96W_047/001g004t079r000p000P000b10184h61L032eMB64",
    p => p.type === "pos" && p.wx && p.wx.temp === 79 && p.wx.hum === 61],
  // message with id
  ["W5ABC>APRS,TCPIP*::KG5XYZ-9 :hello there{42",
    p => p.type === "msg" && p.to === "KG5XYZ-9" && p.text === "hello there" && p.msgId === "42"],
  // ack
  ["KG5XYZ-9>APRS,TCPIP*::W5ABC    :ack42",
    p => p.type === "msg" && p.ack === "42"],
  // Mic-E (from live feed, W5CMM near New Orleans: ~30.03N, ~90.24W)
  ["W5CMM>SPPP5V,WIDE1-1,WIDE2-1,qAR,W4NDF:`va9lT)k/`\"4G}444.000MHz T114 +500 Chris-Mobile_%",
    p => p.type === "pos" && Math.abs(p.lat - 30.0093) < 0.01 && p.lng < -90 && p.lng > -91],
];
for (const [line, ok] of checks) {
  const p = w.parsePacket(line);
  if (!p || !ok(p)) {
    throw new Error(`FAIL  4/5  parser: ${line}\n  got: ${JSON.stringify(p)}`);
  }
}
// passcode sanity (known-good pair)
if (w.passcode("N0CALL") !== 13023) {
  throw new Error(`FAIL  4/5  passcode("N0CALL") = ${w.passcode("N0CALL")}, expected 13023`);
}
console.log(`PASS  4/5  parser + passcode (${checks.length} packets)`);

// ── Test 5: version sync ─────────────────────────────────────────────────
const vHtml = js.match(/const VERSION="([^"]+)"/)?.[1];
const sw = fs.readFileSync(path.join(root, "sw.js"), "utf8");
const vSw = sw.match(/const CACHE = "packetmap-([^"]+)"/)?.[1];
const readme = fs.readFileSync(path.join(root, "README.md"), "utf8");
const vReadme = readme.match(/version-([0-9.]+)-/)?.[1];
if (!vHtml || vHtml !== vSw || vHtml !== vReadme) {
  throw new Error(`FAIL  5/5  version mismatch: index.html=${vHtml} sw.js=${vSw} README=${vReadme}`);
}
console.log(`PASS  5/5  version sync (${vHtml})`);
console.log("\nAll smoke tests passed.");
process.exit(0);
