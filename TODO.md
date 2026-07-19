# PacketMap — TODO / Backlog

Running list of things to build or investigate. Newest thinking on top.

---

## Data collection

### Direct APRS-IS stream (no Cloudflare, no API keys)

**Status:** idea / not started

**Context:** today the live feed runs through the `worker/` Cloudflare Worker
(WebSocket → APRS-IS TCP). This item is about talking to the open APRS-IS
network directly — or through a self-hosted relay — so there's no commercial
gateway and no API keys anywhere in the path.

Skip web APIs entirely — the APRS-IS network itself is the open stream. It's
plain TCP text, community-run volunteer infrastructure, with no CDN or
commercial gateway in front of it.

#### Connection details

- **Protocol:** Raw TCP, CRLF-terminated text lines
- **Host:** `rotate.aprs2.net` (round-robin) or a regional server like
  `noam.aprs2.net` for North America
- **Port 14580** — user-defined filter port (recommended)
- **Port 10152** — full firehose feed (heavy; can overwhelm clients and bandwidth)

#### Receive-only login

No valid passcode required for read-only. Send a login line, then a filter:

```
user YOURCALL pass -1 vers myapp 1.0
filter r/30.5/-90.1/200
```

That filter gives a 200 km radius feed around the given lat/lon. Packets arrive
as raw APRS text lines — trivial to parse. In Python, `aprslib` handles the
decode.

#### Browser caveat

Raw TCP won't work from a web page. For a single-file HTML app, run a tiny
WebSocket-to-TCP relay you host yourself (~30 lines of Node or Python).
Server-side or Raspberry Pi projects can connect directly.

#### Legal note

Consuming the feed read-only is fine. Transmitting into APRS-IS (and out to RF)
requires a valid amateur callsign and real passcode.
