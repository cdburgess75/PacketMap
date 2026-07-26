# PacketMap (Flutter)

The native build of [PacketMap](../../): Windows, Linux, macOS and Android
today, iOS when we get to it. No app store required for any of the desktop
targets — they ship as ordinary executables.

The PWA stays in service as the zero-install web version. This exists for the
one thing a browser can never do: **keep beaconing with the screen off.**

## Why native

| | PWA | Flutter |
|---|---|---|
| Install | Browser, no store | `.exe` / AppImage / `.dmg` / APK |
| Transport | WebSocket to a javAPRSSrvr endpoint | **Raw TCP** to `rotate.aprs2.net:14580` |
| Background beaconing | No — the OS suspends the page | Yes, with a foreground service on Android |
| TNC over Bluetooth / USB | Not reachable from Safari | Possible later |

Raw TCP also removes the framing trap that cost the PWA a release: a socket is
always a CRLF-delimited stream, so there is no frame-per-record special case on
the way out. See `aprs_core`'s README for the full story.

## Layout

```
lib/
  main.dart              app shell, header, five-tab nav
  src/
    aprs_client.dart     TCP APRS-IS: login, framing, reconnect, wake recovery
    app_state.dart       wiring: GPS in, packets in, beacons out
    settings.dart        user settings + persistence
    station_store.dart   stations, tails, range, dead reckoning, pruning
    message_store.dart   messages, acks, retries, bulletins
    theme.dart           the Deep Obsidian palette, shared with the PWA
    ui/                  map, heard, messages, raw, setup
test/
  engine_test.dart       the logic that decides what goes on the air
```

Protocol work lives in [`aprs_core`](../aprs_core/), not here — it is shared
with the PWA and held to it by a parity harness.

## Running it

```sh
flutter pub get
flutter run -d windows      # or linux, macos, android
```

Linux desktop additionally needs GTK dev headers (`libgtk-3-dev` on Debian and
friends); everything else is stock Flutter.

macOS and iOS need Xcode, which cannot be scripted — install it from the Mac
App Store (~15 GB), then:

```sh
sudo xcodebuild -license accept
sudo xcode-select --install
brew install cocoapods
flutter doctor -v            # work whatever it still flags
```

## Platform capabilities

These are already configured, and each one is silent-failure territory if it
goes missing:

| Platform | What it needed | Why |
|---|---|---|
| macOS | `com.apple.security.network.client` | The app is sandboxed. Without it the TCP connection to APRS-IS fails with no error — it just never connects. |
| macOS | `NSLocationWhenInUseUsageDescription` + location entitlement | No prompt, no fix |
| iOS | `NSLocation…UsageDescription` ×2 | iOS terminates an app that asks for location without a usage string |
| iOS | `UIBackgroundModes: location` | Beaconing with the screen off. Expect to justify this at App Store review. |
| Android | `INTERNET` | Without it there is no APRS-IS connection at all |
| Android | fine/coarse + background location, foreground service | Position, and beaconing with the screen off |

Android's `ACCESS_BACKGROUND_LOCATION` must be requested *after* foreground
location has already been granted, and only alongside a running foreground
service — Android rejects it otherwise.

## Tests

```sh
flutter analyze     # no issues
flutter test        # engine tests, no device needed
```

The engine tests cover the decisions with consequences: that a message which
never left the device is deferred rather than spending an on-air retry, that a
pending message keeps its ack lookup across a restart (and is failed rather
than left "sending" when too old to be acked), that bulletins are never acked,
that dead reckoning gives up on stale fixes, and that the server-side filter is
built the way APRS-IS expects.

## Not done yet

- Weather history graphs and NWS alert polygons (both exist in the PWA)
- Notifications, share and GPX export
- Android foreground service for background beaconing — the reason this build
  exists, and the next thing worth doing
- APRS symbol sprites; stations currently render as coloured dots
