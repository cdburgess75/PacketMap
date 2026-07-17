# PacketMap

![version](https://img.shields.io/badge/version-2026.07.16.001-2E8B7A)
![license](https://img.shields.io/badge/license-MIT-blue)

**Live APRS map in your pocket.** Real-time stations around your GPS position,
SmartBeaconing, APRS messaging, track tails, and a raw packet console. A
single-file PWA: install it from the browser, works offline, no account, and
all data stays on your device.

**Live app:** https://cdburgess75.github.io/PacketMap/

Sibling apps: [PileUp](https://github.com/cdburgess75/PileUp) (POTA/SOTA log) ·
[SkyWave](https://github.com/cdburgess75/SkyWave) (shortwave guide)

## Features

- Real-time APRS-IS feed filtered around your GPS position (radius configurable)
- Proper APRS symbols, station info panel (course/speed/altitude, weather, raw packet)
- Track tails with on-device history (IndexedDB, 7-day retention)
- Position beaconing with SmartBeaconing (corner pegging) plus a Send Now button
- Two-way APRS messaging with automatic acks and retries
- Watchlist with alerts when a starred callsign is heard or messages you
- Raw packet console with filter and pause
- Installable PWA: offline app shell, cached map tiles, update banner

## How it connects (the bridge)

Browsers cannot open TCP sockets, so PacketMap talks to APRS-IS through a tiny
Cloudflare Worker that does nothing but pipe a WebSocket to
`rotate.aprs2.net:14580`. All APRS logic (login, filters, packets) lives in the
app; the Worker is a dumb pipe with a hardcoded upstream, so it cannot be
abused as an open proxy.

Deploy your own copy (free Cloudflare account, no credit card):

```
cd worker
npx wrangler login
npx wrangler deploy
```

Then paste the printed URL (as `wss://packetmap-bridge.<you>.workers.dev`) into
SETUP > Bridge URL. For local development the app defaults to
`ws://127.0.0.1:8787` (run `npx wrangler dev --local` in `worker/`).

## Transmitting

Enter your callsign in SETUP (the APRS-IS passcode is computed automatically)
and switch Transmit on. Beacons and messages are gated to RF by APRS-IS
igates: **a valid amateur radio license is required.** Leave the callsign
blank for a receive-only map.

## Development

No build step. `index.html` is the app; edit it directly. The vendored blocks
(Leaflet 1.9.4 BSD-2-Clause, aprs-symbols sprites CC BY 4.0) are marked with
banner comments; do not hand-edit those.

```
npm install    # dev only: jsdom for the smoke tests
npm test       # 5 smoke tests: syntax, DOM ids, jsdom boot, parser, version sync
npx serve .    # local dev server
```

## Credits

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors
- [Leaflet](https://leafletjs.com/) © Vladimir Agafonkin, BSD-2-Clause
- APRS symbols from [hessu/aprs-symbols](https://github.com/hessu/aprs-symbols), CC BY 4.0
- APRS is a registered trademark of Bob Bruninga, WB4APR (SK)

## License

MIT
