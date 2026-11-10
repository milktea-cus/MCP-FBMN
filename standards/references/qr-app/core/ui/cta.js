export function renderCTA(config, mount=document.body){
  const c = config.contact || config.cta || {};
  if (!c.zalo && !c.phone && !c.map) return;
  const box = document.createElement("div");
  box.className = "customer-cta";
  box.innerHTML = `${c.phone ? `<a href="tel:${c.phone}">Gọi</a>` : ""}${c.map ? `<a href="${c.map}" target="_blank" rel="noopener">Đường</a>` : ""}${c.zalo ? `<a href="${c.zalo}" target="_blank" rel="noopener">Zalo</a>` : ""}`;
  mount.appendChild(box);
}
