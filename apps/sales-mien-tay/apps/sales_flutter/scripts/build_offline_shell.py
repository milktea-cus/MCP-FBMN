"""Precache immutable app-shell assets only; never cache business API responses."""
import hashlib
import json
import os
from pathlib import Path

root = Path("build/web")
files = [p for p in root.rglob("*") if p.is_file() and not p.name.endswith(".map")
         and p.name not in ("filed-sw.js", "flutter_service_worker.js", "version.json")]
version = hashlib.sha256()
for p in sorted(files):
    version.update(p.relative_to(root).as_posix().encode())
    version.update(p.read_bytes())
urls = ["/" + p.relative_to(root).as_posix() for p in sorted(files)]
# Build manifest is fetched network-first; never cached with business content.
# FBMN_BUILD_SHA is the value compiled into main.dart.js in build-vercel.sh.
build_sha = os.environ.get("FBMN_BUILD_SHA") or os.environ.get("VERCEL_GIT_COMMIT_SHA") or os.environ.get("GITHUB_SHA") or version.hexdigest()[:16]
(root / "version.json").write_text(json.dumps({
    "version": build_sha, "shell": version.hexdigest()[:16]
}, separators=(",", ":")))
html = root / "index.html"
markup = html.read_text()
# PWA iOS: one in-app action activates the WAITING worker and reloads exactly
# once after controllerchange. Do not clear IndexedDB, CacheStorage globally,
# cookies, localStorage, or unsubmitted survey/outbox records.
inject = """<script src="/fieldwork-push.js"></script><script>
(() => {
  if (!('serviceWorker' in navigator)) return;
  let registrationPromise;
  const registration = () => registrationPromise || (registrationPromise =
    navigator.serviceWorker.register('/filed-sw.js', {updateViaCache:'none'}));
  async function check(running) {
    const reg = await registration();
    const response = await fetch('/version.json?t=' + Date.now(),
      {cache:'no-store',headers:{'Cache-Control':'no-cache'}});
    if (!response.ok) throw Error('Không kiểm tra được bản mới: HTTP ' + response.status);
    const manifest = await response.json();
    if (typeof manifest.version !== 'string' || !manifest.version) throw Error('Thiếu mã bản mới');
    if (manifest.version !== running) await reg.update();
    return JSON.stringify({supported:true,running:running,latest:manifest.version,
      shell:manifest.shell,available:manifest.version !== running,waiting:!!reg.waiting});
  }
  async function activate() {
    const reg = await registration();
    await reg.update();
    if (!reg.waiting) {
      await new Promise((resolve,reject) => {
        const timer = setTimeout(() => reject(Error('Bản mới chưa tải xong, vui lòng thử lại')), 20000);
        const checkWaiting = () => {
          if (reg.waiting) { clearTimeout(timer); resolve(); }
        };
        reg.addEventListener('updatefound', () => {
          const installing = reg.installing;
          if (installing) installing.addEventListener('statechange', checkWaiting);
          checkWaiting();
        });
        if (reg.installing) reg.installing.addEventListener('statechange', checkWaiting);
        checkWaiting();
      });
    }
    await new Promise((resolve,reject) => {
      let done = false;
      const finish = () => {
        if (done) return; done = true;
        navigator.serviceWorker.removeEventListener('controllerchange',finish);
        resolve();
      };
      navigator.serviceWorker.addEventListener('controllerchange',finish);
      reg.waiting.postMessage({type:'FBMN_SKIP_WAITING'});
      setTimeout(() => {
        if (!done) reject(Error('Chưa kích hoạt được bản mới. Dữ liệu trên máy vẫn an toàn.'));
      },20000);
    });
    // A single reload after activation, not a two-close iPhone workaround.
    window.location.reload();
    return true;
  }
  window.fbmnCheckPwaUpdate = check;
  window.fbmnActivatePwaUpdate = activate;
  registration().then(reg => reg.update()).catch(() => {});
})();
</script>"""
markup = markup.replace("</body>", inject + "</body>")
html.write_text(markup)
script = """
const CACHE = 'filed-shell-VERSION';
const ASSETS = URLS;
self.addEventListener('install', e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => {
  // First install can activate immediately; updates wait for an explicit tap.
  if (!self.registration.active) return self.skipWaiting();
})));
self.addEventListener('message', e => {
  if (e.data && e.data.type === 'FBMN_SKIP_WAITING') self.skipWaiting();
});
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
