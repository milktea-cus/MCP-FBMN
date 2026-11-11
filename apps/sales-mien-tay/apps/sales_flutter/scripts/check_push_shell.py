"""Verify generated PWA service worker supports background notifications safely."""
from pathlib import Path
app=Path('build/web')
sw=(app/'filed-sw.js').read_text()
js=(app/'fieldwork-push.js').read_text()
index=(app/'index.html').read_text()
assert "addEventListener('push'" in sw
assert "showNotification(" in sw
assert "addEventListener('notificationclick'" in sw
assert "clients.openWindow('/')" in sw
assert "u.pathname.startsWith('/api/')" in sw
assert "caches.open(CACHE)" in sw
assert "Notification.requestPermission()" in js
assert "userVisibleOnly:true" in js
assert "pushManager.subscribe(" in js
assert 'src="/fieldwork-push.js"' in index
assert "field-work-alert" in sw
assert "Bạn có thông báo công việc mới" in sw
assert not any(x in sw for x in ['DATABASE_URL','Bearer ', 'p256dh','customer_name'])
print('PASS: browser Push, safe lock-screen payload, no API caching, explicit permission')
