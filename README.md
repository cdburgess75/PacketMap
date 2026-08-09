<div align="center">

<img src="icons/og-image.png" alt="PacketMap — live APRS map with GPS beaconing and messaging" width="760">

# PacketMap

### The live map of amateur radio's data network — in your pocket, centred on you.

**One HTML file. No app store, no account, no server to host.**<br>
Watch thousands of stations beacon their position and weather in real time — then join in from your phone's GPS.

<br>

<a href="https://cdburgess75.github.io/PacketMap/">
<img src="https://img.shields.io/badge/%E2%96%B6%20TRY%20THE%20LIVE%20APP-Open%20in%20your%20browser-40ECC1?style=for-the-badge&labelColor=090B10&color=40ECC1" alt="Try the live app" height="52">
</a>

<sub>Opens instantly · works offline · installs to your home screen in two taps</sub>

<br><br>

[![version](https://img.shields.io/badge/version-2026.07.26.011-D46900?style=flat-square)](CHANGELOG.md)
[![smoke tests](https://github.com/cdburgess75/PacketMap/actions/workflows/smoke.yml/badge.svg)](https://github.com/cdburgess75/PacketMap/actions/workflows/smoke.yml)
[![PWA](https://img.shields.io/badge/PWA-installable_%C2%B7_offline-D46900?style=flat-square)](#-install-it-on-your-phone-2-taps)
[![runtime dependencies](https://img.shields.io/badge/runtime_deps-0-106652?style=flat-square)](#-tech-stack)
[![license](https://img.shields.io/badge/license-MIT-1061CC?style=flat-square)](LICENSE)

<br>

<!-- ─────────────────────────────────────────────────────────────────────────
     HERO VISUAL — replace with an animated GIF (approx. 400×860, under 8 MB)
     Record on a phone: open the app, let stations populate, tap a station to
     open its detail sheet, then tap GO to enter driving mode.
     Save as: docs/images/demo.gif
     ──────────────────────────────────────────────────────────────────────── -->
> **📽️ Hero GIF goes here** → save as `docs/images/demo.gif`, then replace this
> block with:
> `<img src="docs/images/demo.gif" alt="PacketMap in action: live stations appearing on the map, a station detail sheet opening, and driving mode engaging" width="320">`

<br>

<sub>Part of the same family as [PileUp](https://github.com/cdburgess75/PileUp) (POTA/SOTA log) and [SkyWave](https://github.com/cdburgess75/SkyWave) (shortwave guide).</sub>

</div>

---

## 🛰️ What is this?

**APRS** (Automatic Packet Reporting System) is amateur radio's tactical data network. Thousands of stations broadcast their position, weather, and short messages over the air; internet gateways merge it all into the worldwide **APRS-IS** feed.

PacketMap puts that live feed on a map — centred on *you* — and lets you join in with nothing but a browser.

| Instead of… | PacketMap gives you… |
|---|---|
| A desktop site that needs a big screen and a connection | An installable app, built mobile-first, whose shell and seen map tiles work **offline** |
| Watching the network while staying invisible on it | Your callsign + a Transmit switch — SmartBeaconing puts you on the air (and on [aprs.fi](https://aprs.fi/)) from your phone's GPS |
| A map that hides the protocol behind it | Tap any station for decoded weather, course and altitude — plus the raw packet. The RAW tab streams the live feed. |
| Messaging that needs a radio or a paid app | Full two-way APRS messaging with automatic acks and retries |
| Standing up a proxy to reach APRS-IS from a browser | A direct WebSocket connection — **nothing to deploy** |

---

## ✨ Features

<div align="center">

<img src="docs/images/heard.png" alt="Heard list showing nearby APRS stations sorted by distance, with symbol, callsign, speed and bearing" width="230">
&nbsp;
<img src="docs/images/station-detail.png" alt="Station detail sheet with 24-hour weather sparklines for temperature, barometer, wind and humidity" width="230">
&nbsp;
<img src="docs/images/messages.png" alt="Two-way APRS message thread showing sent and received messages with acknowledgements" width="230">

<sub>Heard list · Station detail with 24 h weather history · Two-way messaging</sub>

</div>

<br>

**🗺️ Live map** — Real-time APRS-IS feed on OpenStreetMap with authentic APRS symbols. The server-side filter follows your GPS. Adjustable radius (10–500 km), callsign search, one-tap fit-to-stations.

**🚗 Driving mode** — One green **GO** button: full screen, follow-me tracking, and a screen-wake lock together. The map stays on you and the phone stays awake.

**📡 Beaconing** — SmartBeaconing scales your rate with speed and pegs corners on turns (~20 min parked, up to once a minute at highway speed). One-tap **SEND NOW**, a master Transmit switch, and configurable symbol / SSID / comment. Your APRS-IS passcode is computed automatically.

**💬 Messaging** — Conversation threads per callsign, automatic `{id}` sequencing, retries until acked, incoming auto-ack, and unread badges.

**☰ Heard list** — Every station on the map, sortable by distance, recency or callsign. Filter as you type; tap to jump to it. Often faster than hunting for an icon.

**🌤️ Weather** — Weather stations get 24-hour sparklines for temperature, barometer, wind and humidity, drawn on-device with no chart library. The **☀** button asks **WXBOT**, an APRS robot, for a forecast — which works over RF with no internet at all.

**⚠️ NWS alerts** — Active US watch and warning polygons, severity-coloured. Alerts covering *your* position draw solid, pin a standing bar to the map, and raise a notification.

**🧠 Map intelligence** — Range circles from a station's own PHG/RNG data, and dead-reckoned ghost markers projecting where a moving station should be right now.

**📻 Raw console** — The full live packet stream with filter and pause. The whole protocol, visible.

**🔒 Privacy** — Receive-only mode needs no callsign at all. Nothing leaves your browser except the packets you deliberately transmit.

<details>
<summary><b>More: bulletins, track tails, watchlist, GPX export, offline…</b></summary>

<br>

| Area | What it does |
|---|---|
| **Bulletins** | `BLN0`–`BLN9` / `BLNA`–`BLNZ` broadcasts — net announcements, club notices, relayed weather — collected at the top of Messages. |
| **Track tails** | Colour-coded polylines for moving stations, persisted on-device (7-day retention), re-seeded on launch, exportable as GPX. |
| **Watchlist presence** | Star callsigns (prefix `*` supported) and know when someone is on the air: a pinned strip with green/grey presence dots, an alert when a station appears **and when it goes quiet**, and a 🔔 activity log of the last 50 comings and goings. Works worldwide — watched calls ride the server-side filter, not just your radius. |
| **Station actions** | One-tap **navigate** (Apple/Google Maps), **share**, and **GPX** export of any station's track. |
| **Packet parser** | Uncompressed, compressed (base91), Mic-E, objects, items, weather, status, messages, PHG/RNG, and the `!DAO!` precision addendum — all decoded in the browser. |
| **Your position** | Live self-marker showing *your* APRS symbol, accuracy circle, and follow-me. No GPS? Long-press the map to set position by hand. |
| **Interface** | Dark and light themes, three text sizes, full-screen Messages / Raw tabs. |
| **Offline** | Service-worker shell cache, 1500-tile OSM cache, and an update banner when a new release ships. |

</details>

---

## 🧰 Tech stack

![Vanilla JS](https://img.shields.io/badge/Vanilla_JS-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![Leaflet](https://img.shields.io/badge/Leaflet-199900?style=for-the-badge&logo=leaflet&logoColor=white)
![PWA](https://img.shields.io/badge/PWA-5A0FC8?style=for-the-badge&logo=pwa&logoColor=white)
![OpenStreetMap](https://img.shields.io/badge/OpenStreetMap-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white)
<br>
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Cloudflare Workers](https://img.shields.io/badge/Cloudflare_Workers-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)

> **No framework, no bundler, no build step.** The entire web app is one `index.html` with **zero runtime dependencies** — Leaflet and the APRS symbol sheets are vendored into the file. Node and jsdom are used only for the test suite; the app itself needs nothing but a browser.

<details>
<summary><b>Repository layout</b></summary>

```
PacketMap/
├── index.html                 # the entire web app — markup, styles, logic, vendored Leaflet + symbols
├── sw.js                      # service worker: app-shell cache + OSM tile cache
├── manifest.webmanifest       # PWA manifest (icons, theme, display mode)
├── worker/                    # optional Cloudflare Worker bridge (WebSocket ↔ APRS-IS TCP)
├── dart/
│   ├── aprs_core/             # APRS protocol layer in pure Dart, shared with the native build
│   └── packetmap_app/         # Flutter app: Windows, Linux, macOS, Android
├── icons/                     # app icons (SVG + PNG) and the social-preview image
├── docs/images/               # screenshots used by this README
└── test/smoke.mjs             # smoke suite: syntax, DOM ids, jsdom boot, parser, version sync
```

</details>

---

## 📲 Install it on your phone (2 taps)

PacketMap is a **Progressive Web App** — it installs straight from the browser. No app store, no account, no sideloading. Once installed it launches from your home screen, runs full-screen without browser chrome, and works offline.

<div align="center">

<!-- ─────────────────────────────────────────────────────────────────────────
     OPTIONAL — a short screen recording of the install flow reassures people.
     Record: Safari → Share sheet → Add to Home Screen → tap the new icon.
     Save as: docs/images/install-ios.gif
     ──────────────────────────────────────────────────────────────────────── -->
> **📽️ Optional install GIF** → `docs/images/install-ios.gif`

</div>

### 🍎 iPhone & iPad (Safari)

> Safari is required — Chrome on iOS cannot install web apps.

1. Open **<https://cdburgess75.github.io/PacketMap/>** in **Safari**
2. Tap the **Share** button — the square with an arrow, at the bottom of the screen
3. Scroll down and tap **Add to Home Screen**
4. Tap **Add**

PacketMap now sits on your home screen with its own icon. **Launch it from there**, not from Safari — that's what gives you the full-screen, app-like experience.

### 🤖 Android (Chrome)

1. Open **<https://cdburgess75.github.io/PacketMap/>** in **Chrome**
2. Tap the **⋮** menu (top right)
3. Tap **Install app** — or **Add to Home screen** on older versions
4. Confirm **Install**

Chrome often shows an **"Install"** banner at the bottom of the screen on its own; tapping that does the same thing.

### 💻 Windows, macOS & Linux (Chrome or Edge)

1. Open **<https://cdburgess75.github.io/PacketMap/>**
2. Click the **install icon** (⊕ or 🖥️) at the right-hand end of the address bar
3. Click **Install**

You get a real windowed app with its own taskbar / dock / Start-menu entry, launchable offline.

> **💡 Desktop is a first-class home.** Unlike a phone, a desktop OS doesn't suspend background windows — an installed PacketMap holds its APRS-IS connection all day as a monitoring station. No GPS on your desktop? Long-press (or click-hold) the map to set your position by hand.

---

## 🚀 Quick start (local development)

### Prerequisites

| Requirement | Why |
|---|---|
| A modern browser | That's all the **app** needs — there is no build step |
| [Node.js](https://nodejs.org/) ≥ 18 | Only for the test suite (`jsdom` is the sole dev dependency) |
| [Git](https://git-scm.com/) | To clone the repository |

### 1. Clone

```bash
git clone https://github.com/cdburgess75/PacketMap.git
cd PacketMap
```

### 2. Install

```bash
npm install          # dev-only: jsdom, for the test suite
```

> Nothing is installed for the app itself — `index.html` has zero runtime dependencies.

### 3. Run

```bash
npx serve .          # serves the app at http://localhost:3000
```

Open **<http://localhost:3000>** and you're live on the APRS network. New Orleans — the default map centre — always has traffic on the air.

<details>
<summary><b>Optional: run the local APRS-IS bridge</b></summary>

<br>

```bash
cd worker && npx wrangler dev --local    # bridge on :8787
```

On `localhost` the app looks for this bridge automatically. To skip it and use the direct feed, point **Setup → Network → Server** at `wss://ametx.com:8888`.

</details>

### 4. Test

```bash
npm test
```

Five checks in about a second:

| # | Check | Catches |
|---|---|---|
| 1 | App script parses (`new Function`) | Syntax errors anywhere in the app |
| 2 | Every `$()` / `getElementById` has a matching `id` | Typos between markup and logic |
| 3 | Full boot inside jsdom | Runtime errors on startup, missing elements |
| 4 | Parser vectors: position / weather / Mic-E / message + passcode | Protocol regressions |
| 5 | `VERSION` === `sw.js` cache name === README badge | Version drift between app, cache and docs |

---

## 🎛️ Using PacketMap

<div align="center">

<img src="docs/images/setup.png" alt="Setup screen showing callsign, SSID, APRS symbol picker and transmit switch" width="230">
&nbsp;
<img src="docs/images/raw-console.png" alt="Raw packet console streaming live APRS traffic with source callsigns highlighted" width="230">
&nbsp;
<img src="docs/images/map-light.png" alt="PacketMap in light theme showing stations on an OpenStreetMap base layer" width="230">

<sub>Setup · Raw packet console · Light theme</sub>

</div>

<br>

Five tabs along the bottom — **⌖ Map**, **☰ Heard**, **✉ Msgs**, **∿ Raw**, **⚙ Setup**.

**First run.** Allow the location prompt so the map centres on you and the feed follows your GPS. No prompt? Tap **◎** on the map, or long-press the map to set your position by hand.

**Before you drive.** Tap the green **GO** button — full screen, follow-me tracking, and the screen stays awake, all in one tap. Tap **EXIT** to come back.

**Going on the air.** In **Setup → My station**, enter your callsign and SSID (−9 mobile, −7 HT, −5 phone), pick a symbol, write your beacon text. Flip **Transmit**, and **SEND NOW** beacons immediately — SmartBeaconing handles the rest. Then look yourself up on [aprs.fi](https://aprs.fi/): you're a real station now.

> ⚠️ **Transmitting on APRS requires an amateur radio license.** Receive-only mode works with no callsign at all.

**Messaging.** Tap a station → **MSG**, or start a thread by callsign. Sent messages show **sending → ✓ ack** as the other station confirms; incoming messages are acked automatically.

**Watching friends.** Tap **★** on any station, or add callsigns (prefix `*` ok) in Setup. Watched stations get a star on the map and raise an alert when they appear or write to you.

---

## 🔌 How it connects

Browsers can't open raw TCP sockets, and the core APRS-IS pool (`rotate.aprs2.net:14580`) is plain-text TCP only. But APRS-IS servers running `javAPRSSrvr` expose a **native WebSocket port**, and at least one serves it over **TLS** — so PacketMap connects straight to the network with **nothing to host**:

```
┌─────────────────┐   WebSocket (wss)   ┌────────────────────────────┐
│  PacketMap PWA  │ ◄─────────────────► │   APRS-IS  (javAPRSSrvr)   │
│  (your browser) │  login · filter ·   │   wss://ametx.com:8888     │
└─────────────────┘  parse · transmit   │   a node on the world feed │
                                         └────────────────────────────┘
```

The app speaks the standard APRS-IS protocol itself — login, passcode, radius filter, parsing, and (with a callsign) transmit — exactly as it would over TCP. Receive-only needs no callsign and no account.

**Bring your own endpoint.** **Setup → Network → Server** accepts your own `wss://` APRS-IS endpoint, or a self-hosted [Cloudflare Worker](worker/) bridge — a ~70-line dumb pipe on the free tier, with the upstream host hardcoded so it can't be abused as an open proxy.

**Network access is pinned** by a `Content-Security-Policy` meta tag to exactly: OSM tiles, the APRS-IS WebSocket endpoint(s), `api.weather.gov`, and any `*.workers.dev` bridge. Nothing else can be contacted.

---

## 📱 Native builds

A **Flutter** build lives in [`dart/packetmap_app`](dart/packetmap_app/), targeting Windows, Linux, macOS and Android — no app store required for any desktop target. It exists for the one thing a browser cannot do: **keep beaconing with the screen off.**

The APRS protocol layer is shared as a pure-Dart package, [`dart/aprs_core`](dart/aprs_core/), and held to the web app by a parity harness — the same packet vectors are parsed by both implementations and diffed field by field.

See [`docs/FLUTTER-HANDOFF.md`](docs/FLUTTER-HANDOFF.md) to get started.

---

## 🤝 Contributing

Contributions are welcome. To keep the project true to its design goals:

1. **Open an issue first** for anything beyond a small fix, so the approach can be agreed before you invest time.
2. **Respect the constraints** — single file, zero runtime dependencies, no build step, no APRS logic in the Worker.
3. **Match the existing style** — compact vanilla JS, CSS custom properties for theming (dark and light).
4. **Never weaken the TX gate** — anything that transmits goes through `canTx()`.
5. **Run `npm test`** before pushing; CI runs the same suite on your PR.

---

## 📄 License

Released under the [MIT License](LICENSE).

**Credits:** map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors · [Leaflet](https://leafletjs.com/) © Vladimir Agafonkin (BSD-2-Clause) · APRS symbols from [hessu/aprs-symbols](https://github.com/hessu/aprs-symbols) (CC BY 4.0) · weather alerts from the [US National Weather Service](https://www.weather.gov/documentation/services-web-api) · APRS is a registered trademark of Bob Bruninga, WB4APR (SK).

<div align="center">

<br>

### [▶ Open the live app](https://cdburgess75.github.io/PacketMap/)

<sub>73 📻</sub>

</div>
