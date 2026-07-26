// Dumps the PWA parser's view of test/vectors.txt in the same canonical shape
// as parity_dump.dart, so the two can be diffed line for line.
// Run from the repo root:  node dart/aprs_core/test/parity_dump.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { JSDOM, VirtualConsole } from "jsdom";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");

const vc = new VirtualConsole();
const dom = new JSDOM(html, {
  url: "https://cdburgess75.github.io/PacketMap/",
  runScripts: "dangerously",
  pretendToBeVisual: true,
  virtualConsole: vc,
  beforeParse(w) {
    const s = {};
    Object.defineProperty(w, "localStorage", {
      value: {
        getItem: k => (k in s ? s[k] : null),
        setItem: (k, v) => { s[k] = String(v); },
        removeItem: k => { delete s[k]; },
        clear: () => {},
        get length() { return Object.keys(s).length; },
        key: i => Object.keys(s)[i] ?? null,
      },
      configurable: true,
    });
    w.matchMedia = () => ({ matches: false, addEventListener() {}, removeEventListener() {} });
    w.fetch = () => Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
    w.WebSocket = function () { this.readyState = 0; this.send = () => {}; this.close = () => {}; };
  },
});
await new Promise(r => setTimeout(r, 400));
const w = dom.window;

const r = (v, dp) => { const f = 10 ** dp; return Math.round(v * f) / f; };

function dump(p) {
  if (!p) return { null: true };
  const m = { src: p.src, dest: p.dest, path: p.path };
  const put = (k, v) => { if (v !== undefined && v !== null) m[k] = v; };
  put("type", p.type);
  put("name", p.name);
  if (p.obj) m.obj = true;
  if (p.kill) m.kill = true;
  put("to", p.to);
  put("text", p.text);
  put("msgId", p.msgId);
  put("ack", p.ack);
  put("rej", p.rej);
  put("status", p.status);
  if (p.lat !== undefined) m.lat = r(p.lat, 6);
  if (p.lng !== undefined) m.lng = r(p.lng, 6);
  put("symT", p.symT);
  put("symC", p.symC);
  put("symO", p.symO);
  put("course", p.course);
  put("speed", p.speed);
  put("alt", p.alt);
  put("phg", p.phg);
  put("rng", p.rng);
  put("comment", p.comment);
  if (p.wx) {
    const wx = {};
    const wput = (k, v) => { if (v !== undefined && v !== null) wx[k] = typeof v === "number" && !Number.isInteger(v) ? r(v, 4) : v; };
    wput("windDir", p.wx.windDir); wput("windSpd", p.wx.windSpd); wput("gust", p.wx.gust);
    wput("temp", p.wx.temp); wput("rain1h", p.wx.rain1h); wput("rain24h", p.wx.rain24h);
    wput("rainMid", p.wx.rainMid); wput("hum", p.wx.hum); wput("baro", p.wx.baro);
    m.wx = wx;
  }
  return m;
}

const canon = m => JSON.stringify(Object.fromEntries(Object.keys(m).sort().map(k => [k, m[k]])));

const vectors = fs.readFileSync(path.join(here, "vectors.txt"), "utf8")
  .split("\n").map(l => l.trimEnd())
  .filter(l => l && !l.startsWith("#"));

for (const line of vectors) console.log(canon(dump(w.parsePacket(line))));
process.exit(0);
