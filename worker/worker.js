// PacketMap APRS-IS bridge — a dumb WebSocket-to-TCP pipe.
//
// The browser cannot open TCP sockets, so this Worker relays bytes between
// the PacketMap PWA (WebSocket) and an APRS-IS server (TCP). It carries no
// APRS logic: the PWA sends the login line, filter commands, and packets
// itself, exactly as it would over a direct TCP connection.
//
// The upstream is hardcoded so this can never be abused as an open TCP proxy.

import { connect } from "cloudflare:sockets";

const UPSTREAM = { hostname: "rotate.aprs2.net", port: 14580 };

export default {
  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("PacketMap APRS-IS bridge. Connect via WebSocket.", {
        status: 200,
        headers: { "content-type": "text/plain" },
      });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();

    let socket;
    try {
      socket = connect(UPSTREAM);
    } catch (e) {
      server.close(1011, "upstream connect failed");
      return new Response(null, { status: 101, webSocket: client });
    }

    const writer = socket.writable.getWriter();
    const enc = new TextEncoder();

    // WebSocket -> TCP
    server.addEventListener("message", async (event) => {
      try {
        const data =
          typeof event.data === "string" ? enc.encode(event.data) : new Uint8Array(event.data);
        await writer.write(data);
      } catch {
        try { server.close(1011, "upstream write failed"); } catch {}
      }
    });

    server.addEventListener("close", () => {
      try { socket.close(); } catch {}
    });
    server.addEventListener("error", () => {
      try { socket.close(); } catch {}
    });

    // TCP -> WebSocket
    (async () => {
      const reader = socket.readable.getReader();
      try {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) break;
          server.send(value);
        }
      } catch {}
      try { server.close(1000, "upstream closed"); } catch {}
    })();

    return new Response(null, { status: 101, webSocket: client });
  },
};
