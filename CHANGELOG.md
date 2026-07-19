# Changelog

All notable changes to PacketMap. Format follows Keep a Changelog; versions
use the repo scheme `YYYY.MM.DD.NNN`.

## [2026.07.19.010] - 2026-07-19

### Changed

- Your GPS position marker — the self dot, its glow/pulse, and the accuracy
  circle — is now coral red (`#fa5252`) instead of blue.

## [2026.07.19.009] - 2026-07-19

### Changed

- New app icon — a bold map pin on a faint grid, in yellow — replacing the old
  pin-with-signal-arcs mark. Regenerated `icon.svg` and the PNGs
  (`apple-touch-icon` 180, `icon-192`, `icon-512` incl. maskable), full-bleed so
  iOS/Android apply their own corner rounding. Installed iOS home-screen
  shortcuts must be deleted and re-added to pick up the new icon.

## [2026.07.19.008] - 2026-07-19

### Fixed

- Fit-to-stations now re-measures the map before fitting (handles a
  just-resized/rotated map) and caps the zoom at 15 so a lone station doesn't
  slam to street level.

## [2026.07.19.007] - 2026-07-19

### Added

- **Callsign labels toggle** — Setup → Map & display → show/hide the callsigns
  beside station icons (labels were always on before).
- **Icon size** — a slider (0.6×–2×) to scale station symbols for dense or
  small-screen maps.
- **Callsign search** — a search box on the map; type a call and press Enter to
  jump to that station (Esc clears). Exact match wins, else first prefix match.
- **Fit-to-stations** — a ⤢ map button that zooms to show every station on the
  map (plus your position).
- **Configurable fade** — the "stale" grayscale/fade timeout (30 min before) is
  now adjustable under Map & display.

### Notes

- Ideas adapted (reimplemented from scratch, no code copied) from APRS-PropView's
  map UX. RF/backend-only PropView features (digipeater, IGate, RF propagation
  meters, analytics) do not apply to a browser APRS-IS app.

## [2026.07.19.006] - 2026-07-19

### Added

- Manual position: long-press the map (or right-click on desktop) and confirm to
  set your position by hand — for beaconing when GPS is unavailable or blocked,
  the way a fixed/home station works. Deliberate by design (a ~1-second hold plus
  a confirmation) so a stray tap can't move you. Clears any accuracy circle and
  drops a steady (non-pulsing) self dot; SmartBeaconing then treats it like any
  fixed position.

## [2026.07.19.005] - 2026-07-19

### Changed

- Tapping SEND NOW without a callsign (or with Transmit off) now jumps straight
  to the Setup tab and focuses the callsign field, instead of only flashing an
  error banner.
- Clearer guidance when a location request is blocked (permission denied) for the
  site — the message points to the Settings reset rather than a generic error.

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
