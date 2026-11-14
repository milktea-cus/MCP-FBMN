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
markup = markup.replace("</body>", """<script src="/fieldwork-push.js"></script><script>
if ('serviceWorker' in navigator) {
  // Installed iPhone PWAs may keep the previous worker across app launches.
  // Check for an updated shell without clearing IndexedDB or forcing reloads
  // while the user is editing an offline draft.
  navigator.serviceWorker.register('/filed-sw.js')
    .then(reg => reg.update()).catch(() => {});
}
</script></body>""")
html.write_text(markup)
script = """
const CACHE = 'filed-shell-VERSION';
const ASSETS = URLS;
self.addEventListener('install', e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(keys =>
  Promise.all(keys.filter(k => k.startsWith('filed-shell-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== self.location.origin || u.pathname.startsWith('/api/')) return;
  if (e.request.mode === 'navigate') {
    // Always check live index.html first. Offline retains the previous shell.
    e.respondWith(fetch(e.request, {cache:'no-store'})
      .catch(() => caches.open(CACHE).then(c => c.match('/index.html')))); return;
  }
  if (ASSETS.includes(u.pathname)) {
    // Bootstrap and executable code must not stay pinned forever in an old
    // iOS Home Screen PWA. Cache remains an offline fallback.
    const activeCode = new Set(['/index.html','/flutter_bootstrap.js',
      '/flutter.js','/main.dart.js']);
    e.respondWith(caches.open(CACHE).then(async c => {
      if (activeCode.has(u.pathname)) {
        try {
          const response = await fetch(e.request, {cache:'no-store'});
          if (response.ok) return response;
        } catch (_) {}
      }
      return await c.match(u.pathname) || fetch(e.request);
    }));
  }
});
self.addEventListener('push', event => {
  event.waitUntil((async () => {
    // The payload contains no customer data, even if the device is locked.
    await self.registration.showNotification('Field Work', {
      body:'Bạn có thông báo công việc mới. Mở ứng dụng để xem.',
      icon:'/icons/Icon-192.png',badge:'/icons/Icon-192.png',
      tag:'field-work-alert',renotify:true,data:{url:'/'}
    });
    if (self.navigator && self.navigator.setAppBadge) {
      try { await self.navigator.setAppBadge(1); } catch (_) {}
    }
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    windows.forEach(c=>c.postMessage({type:'fieldwork-push'}));
  })());
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for (const client of windows) {
      if (new URL(client.url).origin===self.location.origin) {
        await client.focus();client.postMessage({type:'fieldwork-push'});return;
      }
    }
    await self.clients.openWindow('/');
  })());
});
"""
(root / "filed-sw.js").write_text(script.replace("VERSION", version.hexdigest()[:16]).replace("URLS",json.dumps(urls)))
print(f"Offline shell: {len(urls)} assets, no API cache")
