const CACHE = "packetmap-2026.07.26.012";
const TILES = "packetmap-tiles";
const TILE_LIMIT = 1500; // ~30 MB of OSM tiles, trimmed oldest-first
const SHELL = [
  "./",
  "./index.html",
  "./icons/icon.svg",
  "./icons/apple-touch-icon.png",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./manifest.webmanifest"
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)));
});

// The page shows an update banner and posts SKIP_WAITING when the user
// authorizes the update; only then does the new worker take over.
self.addEventListener("message", e => {
  if (e.data && e.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(k => k !== CACHE && k !== TILES).map(k => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// Enumerating a 1500-entry cache on every tile miss would mean ~30 full scans
// for a single pan. Only sweep once per TRIM_EVERY misses, and never overlap.
const TRIM_EVERY = 50;
let sinceTrim = 0, trimming = false;
async function trimTiles() {
  if (++sinceTrim < TRIM_EVERY || trimming) return;
  sinceTrim = 0;
  trimming = true;
  try {
    const c = await caches.open(TILES);
    const keys = await c.keys();
    // cache.keys() is insertion-ordered: delete oldest entries first
    for (let i = 0; i < keys.length - TILE_LIMIT; i++) c.delete(keys[i]);
  } finally {
    trimming = false;
  }
}

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);

  // OSM tiles: cache-first so panning stays fast and works offline
  if (url.hostname === "tile.openstreetmap.org") {
    e.respondWith(
      caches.open(TILES).then(c =>
        c.match(e.request).then(hit => hit || fetch(e.request).then(res => {
          if (res.ok || res.type === "opaque") {
            c.put(e.request, res.clone());
            trimTiles();
          }
          return res;
        }))
      )
    );
    return;
  }

  if (url.origin !== self.location.origin) return;
  // ignoreSearch: the page requests icons as "icon-192.png?v=4" for cache
  // busting, but SHELL precaches the bare path. Without this the precache is
  // never hit and a cold offline start has no icons.
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(cached => {
      const network = fetch(e.request).then(res => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
