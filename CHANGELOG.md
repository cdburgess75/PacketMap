# Changelog

All notable changes to PacketMap. Format follows Keep a Changelog; versions
use the repo scheme `YYYY.MM.DD.NNN`.

## [2026.07.26.004] - 2026-07-26

### Added

- **Weather alerts now have standing UI.** Previously an alert covering you
  raised a five-second toast and then vanished, leaving no way to see what was
  active or re-read it — the wrong treatment for a safety feature. Now:
  - A **bar pinned to the top of the map** for as long as an alert covers you,
    tinted by severity and naming the most severe one. It can be dismissed with
    ✕, and a newly issued alert brings it back. The search box and zoom control
    shift down so nothing is hidden behind it.
  - A **⚠ map button**, badged with the number of active alerts and turning red
    when one covers you, that opens…
  - …an **alert sheet** listing every active alert — event, area, expiry and
    headline — ordered with the ones covering you first and most severe first,
    each marked `HERE`. Tapping an alert frames its outline on the map.
- Turning the feature off in Setup now clears the bar, button, sheet and
  polygons together.

### Fixed

- The alert bar showed whichever alert the NWS happened to return first rather
  than the most severe one, so a Tornado Warning would not have displaced a
  Heat Watch already on screen. Both the bar and the list now rank by severity.

### Changed

- The transient toast for new alerts is gone; the standing bar replaces it. The
  system notification on a newly issued alert is unchanged.

## [2026.07.26.003] - 2026-07-26

### Fixed

- **Header no longer overlaps itself on wide screens.** On a desktop or tablet
  the TX badge collided with the theme toggle in the top-right corner. The
  control buttons were positioned absolutely, with only the brand row reserving
  space for them — on a phone the brand wraps to two lines and pushes the
  status row clear, but on a wide screen it fits on one line and the status row
  rode up underneath the buttons.

  The header is now a two-column grid — brand and status stacked on the left,
  the buttons spanning both rows on the right — so the rows cannot collide at
  any width, text size or font, rather than relying on a breakpoint that the
  text-size control and font picker could invalidate. Verified clean across 54
  combinations (9 widths × 3 text sizes × 2 themes). As a side effect the phone
  header is slightly more compact, since the brand no longer needs to wrap.

## [2026.07.26.002] - 2026-07-26

### Added

- **Heard list — a new tab.** A sortable roster of every station on the map:
  by distance, by recency, or alphabetically, with symbol, distance and
  bearing, speed, comment and age. Filter as you type; tap a row to centre the
  map on that station and open its detail panel. On a busy map — or in a moving
  vehicle — this is usually faster than hunting for an icon.
- **NWS weather alerts (US).** Active National Weather Service watches and
  warnings are drawn as severity-coloured polygons from `api.weather.gov`,
  refreshed every 10 minutes. An alert covering *your* position is drawn solid
  and raises a banner plus a system notification; the rest of your state is
  drawn dashed so you can see weather coming before it arrives. Off switches
  cleanly in **Setup → Weather alerts**; no API key, no account, US only.
- **Range circles.** Stations that advertise their own coverage via `PHG` or
  `RNG` get a faint circle at that radius, using the standard APRS range
  formula. Useful for seeing which digipeater should be hearing you.
- **Dead reckoning.** Moving stations get a dashed ghost marker projecting
  where they should be now, based on their last course and speed. Advances
  between packets, gives up after 30 minutes of silence.
- **Weather history graphs.** Weather stations now show 24-hour sparklines for
  temperature, barometer, wind and humidity in the station panel, drawn from
  on-device history — no chart library, no server. Observations are thinned to
  one per five minutes and kept for three days.
- **Bulletins.** `BLN0`–`BLN9` and `BLNA`–`BLNZ` broadcasts — net
  announcements, club notices, relayed weather — are collected at the top of
  Messages, keyed by sender and slot so a re-send replaces in place. Previously
  these scrolled past in the raw console and were dropped.
- **Navigate, share and GPX.** The station panel gained three actions: open the
  station in Apple or Google Maps for driving directions, share its position
  via the system share sheet (clipboard fallback), and export its track as
  GPX. **Setup → Data** exports every stored track at once.

### Changed

- Parser now decodes the `!DAO!` precision addendum (both the human-readable
  and base-91 forms), adding a third decimal of position accuracy where
  stations send it, and strips the token from the displayed comment.
- Parser now keeps `RNG` from uncompressed positions and decodes the radio-range
  form of the compressed `cs` field, which was previously misread as
  course/speed.
- IndexedDB schema is now version 2, adding a `wx` store. The upgrade is
  guarded so an existing database gains only what it is missing.
- `Content-Security-Policy` gained `https://api.weather.gov` in `connect-src`
  for the alerts feature.

## [2026.07.26.001] - 2026-07-26

### Fixed

- **Transmit works again on the direct APRS-IS feed.** Position beacons,
  outgoing messages and message acks were built correctly but silently
  discarded by the server, so nothing you sent ever reached the network — while
  receive, login and verification all looked perfectly healthy.

  Since 2026.07.19.001 the app connects straight to a native javAPRSSrvr
  WebSocket, which carries **one record per frame with no line terminator**;
  only the Cloudflare Worker bridge relays the CRLF-delimited TCP stream. The
  receive path was taught both framings at the time, but the send path kept
  appending `CRLF` unconditionally. On a frame-per-record link those two bytes
  land *inside* the record, and APRS-IS drops any record containing control
  characters — so every transmitted packet was thrown away without an error.
  The local RAW echo logs the record before the terminator is added, which is
  why the packets looked flawless on screen.

  Outgoing records are now framed to match the transport the connection is
  actually using, detected from the first inbound data exactly like the receive
  path. The login line keeps its `CRLF` (framing is not yet known when it is
  sent, and both transports accept it).

## [2026.07.25.002] - 2026-07-25

### Fixed

- **Home-screen / PWA icons render correctly again.** In 2026.07.25.001 the
  180 px and 192 px icons shipped as a solid amber square — the pin failed to
  paint while the PNGs were being generated. Regenerated every icon size so the
  obsidian pin is back, and bumped the icon cache-bust to `?v=4` so installed
  home screens and bookmarks re-fetch the corrected art.

## [2026.07.25.001] - 2026-07-25

### Changed

- **New "deep obsidian" color system.** Replaced the flat pure-black surfaces
  with layered obsidian tones (`#090B10` canvas through `#22283A` raised states),
  shifted the muted teal greens to crisp tactical mint/emerald, and refreshed the
  amber, blue and red accents. The light theme was re-derived for higher-contrast
  text on white.
- **Live/status greens now use the bright mint** (`#40ECC1`) — connection LED, TX
  badge, "follow me" button, update banner, focus rings and checkboxes — so they
  stay legible in both themes; the deep emerald (`#106652`) is reserved for
  grounding fills. This also fixes would-be invisible pale-mint indicators in the
  light theme.
- **Signature effects tuned to the new palette** — softer amber logo glow, denser
  CRT scanlines, and darker/desaturated map tiles so the neon markers stand out
  against the basemap.
- **New `--map-bg` and `--self-marker` tokens** wire the Leaflet canvas and your
  own GPS marker into the palette (the self-marker is unified with the red
  accent). Mobile browser `theme-color` follows the new backgrounds.
- **Primary button text is near-black on amber** (was white), so the main
  call-to-action clears WCAG AA in both themes (AAA in dark). Amber is a light
  hue in both themes, so dark ink reads far better on it than white.
- **App icon and favicon recolored** to the new scheme — amber ground with an
  obsidian pin (regenerated at 180 / 192 / 512). The manifest splash/theme
  colors move to `#090B10` and the icon cache-bust bumps to `?v=3`, so
  home-screen installs and bookmarks pick up the new icon.

## [2026.07.20.002] - 2026-07-20

### Changed

- **Your own marker now shows your APRS symbol** (the one you pick in Setup),
  ringed and pulsing coral so it still reads as "you" — instead of a plain coral
  dot. It updates live when you change your symbol. (Your beacon already
  transmitted the selected symbol; this makes the map match.)
- **Messages and Raw tabs are now full-screen** — the header is hidden on those
  two tabs so the conversation/packet list uses the whole height (the bottom tab
  bar stays for navigation). Content drops below the notch on installed iPhones.

## [2026.07.20.001] - 2026-07-20

### Changed

- **Brighter map** — dark-mode tiles go from brightness .72 → .92 (and a bit more
  saturation); light mode gets a slight saturation/contrast boost too.
- **Larger text** in the **Messages** and **RAW** tabs for readability.
- **Tighter header and bottom tab bar** — trimmed padding so less vertical space
  is wasted and the map gets more room.

## [2026.07.19.014] - 2026-07-19

### Added

- **Text size** control: the header **aA** button cycles **Small / Medium / Large**,
  scaling the UI (header, tabs, panels, map controls) while keeping the map itself
  crisp at its natural scale.

### Changed

- The typeface picker (Mono / Sans / Rounded / Serif) moved from the header into
  **Setup → Map & display**, so the header button is dedicated to text size.

## [2026.07.19.013] - 2026-07-19

### Fixed

- The font changer no longer restyles the RAW packet console — packets stay
  monospace (terminal-aligned) whatever UI font you pick. The changer still
  applies to the rest of the app and persists across reloads.

## [2026.07.19.012] - 2026-07-19

### Added

- Full-screen map (⛶) now works in **any orientation** and holds a **Screen Wake
  Lock** so the display won't time out while it's on.
- **Font changer** — an "Aa" button (top-right) cycling Mono / Sans / Rounded / Serif.

### Changed

- Header theme/font controls are now clear rounded buttons; the theme toggle shows
  an **orange sun** (tap → light) or a **blue moon** (tap → dark).
- Bottom tab-bar labels are larger and readable (7.5px → 11px; icons 16 → 20px).

## [2026.07.19.011] - 2026-07-19

### Fixed

- Cache-bust the icon URLs (`apple-touch-icon`, favicon, and manifest icons) with
  `?v=2` so a fresh "Add to Home Screen" fetches the new icon instead of the
  Safari-cached old one.

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
