# PacketMap - repo conventions

Single-file PWA: the entire app is `index.html` (HTML + CSS + JS), `sw.js` is
the service worker, no build step, zero runtime dependencies. Keep it that way.

Two blocks inside `index.html` are VENDORED and must not be hand-edited (they
are marked with banner comments): Leaflet 1.9.4 (JS + CSS) and the base64 APRS
symbol sprite sheets. Everything else is app code; edit it in place.

The `worker/` directory is the Cloudflare Worker bridge (WebSocket to APRS-IS
TCP). It is a dumb pipe: no APRS logic goes in the Worker, ever. The upstream
host is hardcoded on purpose (not an open proxy). Deploy with
`npx wrangler deploy` from `worker/`.

## Versioning - read before any release

Scheme: **`YYYY.MM.DD.NNN`** - UTC date plus a zero-padded three-digit release
counter for that day. First release on a new day starts at `.001`.

The version string lives in **four places that must all change together**:

1. `index.html` - `const VERSION="…"`
2. `sw.js` - `const CACHE = "packetmap-…"` (this triggers the update banner)
3. `README.md` - the shields.io version badge
4. `package.json` - `version` (date only, e.g. `2026.7.16`; npm needs semver)

Smoke test 5 fails if 1-3 disagree, so bump them in the same commit.

## Release checklist

1. Make the change; bump the version in all four places.
2. `npm test` - 5 smoke tests must pass (syntax, DOM-id coverage, jsdom boot,
   parser + passcode vectors, version sync).
3. Verify in a real browser against a live feed: `npx wrangler dev --local` in
   `worker/`, `npx serve .` in the root, open http://localhost:3000. New
   Orleans (29.95, -90.08) always has traffic.
4. Update `CHANGELOG.md` (Keep-a-Changelog style, newest on top).
5. Commit, push to `main`. GitHub Pages deploys automatically; installed PWAs
   show an update banner users must tap.

## Style

- Compact vanilla JS, sections marked with `/* ============ name ============ */` banners.
- Escape everything rendered via `esc()` (text) / `attr()` (attributes).
- Dark theme only, CSS custom properties in `:root` (palette shared with PileUp).
- New `getElementById` targets must exist in markup (smoke test 2 enforces).
- Network access is pinned by the CSP meta tag: OSM tiles + `wss://*.workers.dev`
  + localhost dev. Adding a host means updating the CSP.
- TX safety: anything that transmits must pass through `canTx()` (TX toggle on,
  callsign set, login verified, GPS fix). Never weaken that gate.

## APRS protocol notes (hard-won, do not rediscover)

- APRS-IS login: `user CALL pass PASSCODE vers PacketMap VERSION filter …`;
  passcode is the standard XOR hash over the base call (see `passcode()`).
  `pass -1` = receive-only, server answers `# logresp … unverified`.
- Server-side filter updates mid-session: send a line starting `#filter `.
- Mic-E latitude/message bits ride in the AX.25 destination field; see
  `parseMicE()` and its test vector before touching it.
- Position ambiguity (spaces in lat/lon digits) is parsed as cell-center ("5").
- Compressed positions: base91, `a-j` table chars mean digit overlays `0-9`.
- Messages: addressee padded to 9 chars, `{id` suffix, ack with `:CALL :ackID`.
  Retries 3x at 30s in `txMsg()`.
