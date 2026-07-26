# PacketMap — Flutter build: handoff brief

Hand this to Claude Code on the Mac. It assumes no prior context.

---

## What this is

**PacketMap** is an APRS client: a live map of the amateur-radio APRS network,
with GPS position beaconing and two-way messaging. It already exists and ships
as a single-file PWA at <https://cdburgess75.github.io/PacketMap/> — that stays
in service and is not being replaced.

This brief is about the **native Flutter build**, which already exists in the
repo and runs. It targets **Windows, Linux, macOS and Android now, iOS later**.
App stores are deliberately out of scope for now: desktop targets ship as
ordinary executables, Android sideloads.

**Why a native build at all:** one reason. A browser on iOS/Android suspends a
backgrounded page, so the PWA physically cannot beacon with the screen off, and
cannot receive a message while asleep. A native app can. Everything else the
PWA already does well.

---

## Current state

Everything below is committed on `main` and verified. Nothing is a sketch.

| Piece | State |
|---|---|
| `dart/aprs_core` | **Done.** Protocol layer in pure Dart, zero dependencies. 52 unit tests; 32 parity vectors diffed field-by-field against the PWA parser, all byte-identical. |
| `dart/packetmap_app` | **Runs.** Flutter 3.44.8, five tabs, live map, messaging. `flutter analyze` clean, 19 engine tests pass. |
| Platform capabilities | **Configured** for macOS / iOS / Android (see Traps below). |
| Background beaconing | **Not started.** This is the whole point of the native build. |

### Never been rendered on a screen

The Flutter app was written and tested in a Linux container with no display, no
GTK headers, no Android SDK and no Xcode. It is **type-checked and unit-tested
but has never been drawn**. Expect UI polish to shake out on first run. That is
the single most useful thing a first session can do.

---

## Repo layout

```
index.html                     the PWA — one file, no build step. Still shipping.
sw.js, manifest.webmanifest    PWA service worker + manifest
test/smoke.mjs                 PWA smoke suite (npm test)

dart/aprs_core/                protocol layer, shared, zero deps
  lib/src/parser.dart          uncompressed, compressed base91, Mic-E, objects,
                               items, weather, messages, PHG/RNG, !DAO!
  lib/src/frames.dart          TX builders + login + filter
  lib/src/{passcode,geo,smart_beacon,line_buffer,packet}.dart
  test/run_tests.dart          52 unit tests
  test/vectors.txt             the contract with the PWA — see Parity below

dart/packetmap_app/            the Flutter app
  lib/main.dart                shell, header, five-tab nav
  lib/src/aprs_client.dart     raw TCP APRS-IS client
  lib/src/app_state.dart       GPS in, packets in, beacons out
  lib/src/{settings,station_store,message_store,theme}.dart
  lib/src/ui/                  map, heard, messages, raw, setup, station sheet
  test/engine_test.dart        19 tests
```

---

## Setup on the Mac

Xcode is the long pole — start it downloading before anything else.

```sh
# 1. Xcode from the Mac App Store (~15 GB). Manual; cannot be scripted.
# 2. Then:
sudo xcodebuild -license accept
sudo xcode-select --install
brew install --cask flutter
brew install cocoapods
flutter doctor -v          # work whatever it flags

# 3. Build it
git clone https://github.com/cdburgess75/PacketMap.git
cd PacketMap/dart/packetmap_app
flutter pub get
flutter run -d macos       # fastest first look: no device, no signing, no $99
```

`flutter run -d macos` needs Xcode but nothing else. Android needs Android
Studio separately. iOS-on-device needs the $99 Apple Developer membership —
not required for anything above.

---

## Suggested first session

1. `flutter run -d macos`, get it on screen, fix whatever looks wrong. Layout,
   overflow, contrast, tap targets. This has never been seen.
2. Confirm it actually connects: the header should go
   `CONNECTING… → KF5UUP-5 VERIFIED` and the Raw tab should fill with packets.
   New Orleans (29.95, −90.08) always has traffic.
3. Then pick from *Not done yet* below.

Do **not** start CarPlay work. It needs a navigation entitlement Apple grants
case by case, and the app has no turn-by-turn navigation to justify it.

---

## Traps — hard-won, do not rediscover

**1. Framing (cost the PWA a release).** APRS-IS reaches you two ways and they
frame records differently. Raw TCP is a **CRLF-delimited stream**. A native
javAPRSSrvr WebSocket is **one record per frame, no terminator**. Send with the
wrong framing and APRS-IS *silently discards* every packet — login and receive
keep working perfectly, so it looks fine while nothing you send arrives. The
Flutter app uses raw TCP, so it is always CRLF; `frames.dart` returns records
**without** a terminator and the transport appends. Don't "fix" that.

**2. macOS sandbox.** `com.apple.security.network.client` is required or the
TCP socket never connects, with no error. Already added to both entitlements
files. If you ever regenerate the macOS runner, re-add it.

**3. A suspended process leaves a dead socket looking open.** `readyState` /
the socket object still looks healthy after the OS tore it down, so a send
vanishes. Never trust the socket after a gap: `AprsIsClient.linkAlive` requires
traffic within 90 s (the server keepalive is ~20 s), and `revive()` runs on app
resume. This is why `send()` returns a bool — respect it.

**4. Deferral is not a retry.** A message that never left the device must not
spend one of its three on-air attempts. `MessageStore` retries every 5 s for
30 s while the link returns, *then* starts counting real tries. Getting this
wrong means messages fail after 90 s of doing nothing.

**5. Pending messages must survive a restart.** Restore the ack lookup for
anything younger than 5 minutes, and fail anything older — otherwise a message
sits on "sending" forever after the app is killed. Tested; keep it tested.

**6. Android background location.** `ACCESS_BACKGROUND_LOCATION` must be
requested *after* foreground location is already granted, and only with a
running foreground service. Android rejects it otherwise. Permissions are in
the manifest; the request flow is not written yet.

**7. TX safety.** Anything that transmits goes through `AppState.canTx`
(Transmit on, callsign set, login verified, link alive, GPS fix). Never weaken
it. Transmitting on APRS requires an amateur radio license.

---

## Parity with the PWA

`dart/aprs_core/test/vectors.txt` is parsed by **both** the PWA and `aprs_core`
and the results diffed field by field. All 32 vectors are byte-identical.

```sh
# from the repo root
npm install
node dart/aprs_core/test/parity_dump.mjs > /tmp/pwa.jsonl
cd dart/aprs_core && dart test/parity_dump.dart > /tmp/dart.jsonl
diff /tmp/pwa.jsonl /tmp/dart.jsonl && echo "parity OK"
```

**Any packet that ever causes a bug goes in `vectors.txt`.** If protocol
behaviour must change, change the PWA first, add the vector, then match it in
Dart and re-run parity.

---

## Not done yet, roughly in order of value

1. **Android foreground service for background beaconing.** The entire reason
   this build exists. Nothing else here matters as much.
2. **APRS symbol sprites.** Stations render as coloured dots; the PWA has the
   real symbol sheets (`hessu/aprs-symbols`, CC BY 4.0) already embedded.
3. **Notifications** on watched stations and incoming messages.
4. **NWS weather alert polygons** — `api.weather.gov`, no key. The PWA version
   queries `?point=` for "does this cover me" and `?area=<state>` for the map,
   draws severity-coloured polygons, and keeps a standing bar while an alert
   covers you. Worth copying wholesale; it's a genuine safety feature.
5. **24-hour weather sparklines** in the station sheet.
6. **Share / navigate / GPX export.**
7. **Track persistence** — the app keeps tails in memory only; the PWA persists
   to IndexedDB with 7-day retention and re-seeds on launch.
8. iOS, whenever you want it. The platform config is already in place.

---

## Conventions

- **Protocol logic goes in `aprs_core`, never in the app.** The app wires
  things together; the package knows APRS.
- The PWA is the reference implementation and stays in service. It is not
  deprecated by this.
- PWA versioning is `YYYY.MM.DD.NNN` and must match in four places
  (`index.html`, `sw.js`, `README.md`, `package.json`) — a smoke test enforces
  it. The Flutter app's version is independent.
- `index.html` uses **CRLF** line endings. Scripted edits that rewrite the whole
  file will silently convert it to LF and produce a 5,000-line diff. Check with
  `file index.html`.

## Verification

```sh
npm test                                   # PWA: 5 smoke tests
cd dart/aprs_core   && dart test/run_tests.dart    # 52
cd dart/packetmap_app && flutter analyze && flutter test   # clean + 19
```
