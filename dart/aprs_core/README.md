# aprs_core

The APRS protocol layer of [PacketMap](../../), ported to pure Dart for the
Flutter build (Windows, Linux, macOS, Android — and iOS later). No
dependencies, no platform APIs, no Flutter import: it runs anywhere Dart does,
including the web target.

This package deliberately contains **no UI, no networking, and no storage** —
only the parts that are hard to get right and expensive to get wrong.

## What's in it

| File | Contents |
|---|---|
| `parser.dart` | `parsePacket()` — uncompressed, compressed (base91), Mic-E, objects, items, weather, status, messages, acks/rejects, PHG/RNG, `!DAO!`, position ambiguity |
| `frames.dart` | TX builders: position beacons, messages, acks, the APRS-IS login line and server-side filter |
| `passcode.dart` | The APRS-IS passcode hash, and callsign/SSID formatting |
| `geo.dart` | Haversine, bearing, `destPoint` (dead reckoning), the PHG range formula |
| `smart_beacon.dart` | SmartBeaconing decision logic — speed-scaled rate plus corner pegging |
| `line_buffer.dart` | Record framing for both APRS-IS transports (see below) |
| `packet.dart` | `AprsPacket` / `Wx` value types |

## Framing — read this before writing any transport

APRS-IS reaches you two different ways, and they frame records differently:

- **Raw TCP** (`rotate.aprs2.net:14580`) is a byte stream of **CRLF-delimited**
  records, split across arbitrary chunks.
- **A native javAPRSSrvr WebSocket** delivers **one record per frame, with no
  terminator at all**.

`AprsLineBuffer` handles both on receive. **The same asymmetry applies when you
send**, and getting it wrong fails silently: a trailing CRLF inside a WebSocket
frame lands *inside* the record, and APRS-IS discards any record containing
control characters. Every beacon and message vanishes with no error, while
login and receive keep working perfectly — which is exactly the bug that took
PacketMap 2026.07.26.001 to find.

The builders in `frames.dart` therefore return records **without** a
terminator. Append CRLF on a raw TCP socket; send as-is on a frame-per-record
WebSocket. The login line is the one exception: terminate it with CRLF on
every transport, since framing isn't known yet when it goes out and both
transports accept it.

## Tests

Two layers, both runnable with a bare Dart SDK — no `pub get` required.

**Unit tests** for frames, passcode, geo, SmartBeaconing and framing:

```sh
cd dart/aprs_core
dart test/run_tests.dart
```

**Parity against the PWA.** `test/vectors.txt` is parsed by *both*
implementations and the results diffed field by field, so the port can't drift
from the reference. From the repo root:

```sh
node dart/aprs_core/test/parity_dump.mjs > /tmp/pwa.jsonl     # needs npm install
cd dart/aprs_core && dart test/parity_dump.dart > /tmp/dart.jsonl
diff /tmp/pwa.jsonl /tmp/dart.jsonl && echo "parity OK"
```

Both dumpers emit the same canonical JSON shape, so `diff` is the whole test.
All 32 vectors are currently byte-identical.

**Any packet that ever causes a bug belongs in `vectors.txt`.** That file is
the contract between the two implementations.

## Relationship to the PWA

The PWA (`index.html`) remains the reference implementation and stays in
service — it's the zero-install web version. When protocol behaviour changes,
change it there first, add the vector, and re-run parity.
