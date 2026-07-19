# Changelog

All notable changes to PacketMap. Format follows Keep a Changelog; versions
use the repo scheme `YYYY.MM.DD.NNN`.

## [2026.07.19.004] - 2026-07-19

### Changed

- When a GPS fix is the only thing left before you can transmit, tapping SEND NOW
  now requests your location directly (from that tap, so the browser shows its
  permission prompt) and beacons automatically the moment the fix lands — no need
  to find the ◎ button first. If the location can't be obtained, it says so.

## [2026.07.19.003] - 2026-07-19

### Changed

- SEND NOW is no longer a dead greyed-out button when you can't yet transmit. It
  stays visible and tappable; tapping it while not ready shows exactly what's
  still needed (e.g. "To beacon: turn on Transmit · set your callsign · enable
  GPS (tap ◎)"), and its tooltip lists the same. It only actually beacons once
  the TX gate is satisfied (Transmit on + callsign verified + GPS fix + connected).

## [2026.07.19.002] - 2026-07-19

### Added

- Tap ◎ to actively request GPS. If the automatic location prompt at load was
  dismissed or blocked, ◎ now re-requests it from a user gesture (via
  `getCurrentPosition`) and starts the continuous watch, instead of requiring a
  page reload. Once a fix exists, ◎ toggles follow-me as before.

### Changed

- ◎ button tooltip is now "Find / follow my position".

## [2026.07.19.001] - 2026-07-19

### Added

- Direct APRS-IS connection over WebSocket with **no bridge to host**: the app
  ships a built-in default endpoint (`wss://ametx.com:8888`, a javAPRSSrvr TLS
  WebSocket port on the APRS-IS network) and connects out of the box.
- Endpoint failover: the client rotates through an ordered list of servers,
  advancing past any that fail to connect and sticking with one once logged in.

### Changed

- The SETUP "Bridge URL" field is now an optional "Server" override (a custom
  `wss://` APRS-IS endpoint or your own Cloudflare Worker); leaving it blank uses
  the built-in direct feed. The Worker bridge remains fully supported.
- CSP `connect-src` now allows `wss://ametx.com:8888`.

### Notes

- `wss://ametx.com:8888` is currently the only verified browser-trusted APRS-IS
  WebSocket endpoint; the failover list is ready to hold more as they appear.

## [2026.07.16.003] - 2026-07-16

### Added

- Landscape fullscreen: rotating to landscape on the map tab hides the
  header and tab bar so the map runs edge to edge; a ⛶ button (or
  rotating back to portrait) restores them.

## [2026.07.16.002] - 2026-07-16

### Added

- Light theme with ☀/☾ header toggle and Setup > Appearance buttons,
  using the shared PileUp palette; map tiles render untinted in light mode.
- PileUp-family visual language: glowing letter-spaced wordmark, scanline
  body texture, card-based Setup, icon bottom nav, shared button styles.
- New logo (map pin transmitting) in the family style: amber rounded
  square, dark strokes; regenerated all PNG icons and social og-image.
- README overhaul: hero image, screenshots, feature and test tables,
  bridge diagram; GitHub Actions CI running the smoke suite.

### Fixed

- Receive-only login now uses a persistent PMAP#### pseudo-call; some
  APRS-IS servers reject the N0CALL placeholder.
- Setup view no longer bleeds over other tabs (CSS specificity).
- Hidden alert toast no longer peeks into the header on the map tab.

## [2026.07.16.001] - 2026-07-16

### Added

- Initial release: single-file APRS map PWA.
- Real-time APRS-IS feed via Cloudflare Worker WebSocket bridge (`worker/`),
  radius filter follows your GPS position.
- Full packet parser: uncompressed, compressed (base91), Mic-E, objects,
  items, weather, status, messages/acks.
- Leaflet map (vendored 1.9.4) with OSM tiles, APRS symbol sprites
  (hessu/aprs-symbols), station labels, stale-station dimming.
- Your GPS position as a live blue dot with accuracy circle and follow mode.
- Track tails with IndexedDB history (7-day retention, seeded on boot).
- Station info panel: distance/bearing, course/speed/altitude, weather
  decode, comment, status, raw packet.
- Position beaconing: SmartBeaconing with corner pegging, Send Now button,
  master TX switch, configurable symbol/comment/rates.
- Two-way APRS messaging: conversations, 67-char composer, `{id` sequencing,
  3x30s retries, automatic acks, unread badges.
- Watchlist: star callsigns (prefix `*` supported), banner + system
  notification when heard or messaged.
- Raw packet console: live feed, filter, pause, 2000-line ring buffer.
- PWA: offline app shell, OSM tile cache (1500 tiles, oldest trimmed),
  update banner, installable manifest + icons.
- Smoke tests (syntax, DOM ids, jsdom boot, parser vectors, version sync).
