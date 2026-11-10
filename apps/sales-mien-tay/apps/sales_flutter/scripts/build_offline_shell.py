"""Precache immutable app-shell assets only; never cache business API responses."""
import hashlib
import json
from pathlib import Path

root = Path("build/web")
files = [p for p in root.rglob("*") if p.is_file() and not p.name.endswith(".map")
         and p.name not in ("filed-sw.js", "flutter_service_worker.js")]
version = hashlib.sha256()
for p in sorted(files):
    version.update(p.relative_to(root).as_posix().encode())
    version.update(p.read_bytes())
urls = ["/" + p.relative_to(root).as_posix() for p in sorted(files)]
html = root / "index.html"
markup = html.read_text()
markup = markup.replace("</body>", """<script>
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/filed-sw.js').catch(console.error);
}
</script></body>""")
html.write_text(markup)
script = """
const CACHE = 'filed-shell-VERSION';
const ASSETS = URLS;
self.addEventListener('install', e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS))));
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(keys =>
  Promise.all(keys.filter(k => k.startsWith('filed-shell-') && k !== CACHE).map(k => caches.delete(k))))));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== self.location.origin || u.pathname.startsWith('/api/')) return;
  if (e.request.mode === 'navigate') {
    e.respondWith(fetch(e.request).catch(() => caches.open(CACHE).then(c => c.match('/index.html')))); return;
  }
  if (ASSETS.includes(u.pathname)) {
    e.respondWith(caches.open(CACHE).then(c => c.match(u.pathname)).then(r => r || fetch(e.request)));
  }
});
"""
(root / "filed-sw.js").write_text(script.replace("VERSION", version.hexdigest()[:16]).replace("URLS",json.dumps(urls)))
print(f"Offline shell: {len(urls)} assets, no API cache")
