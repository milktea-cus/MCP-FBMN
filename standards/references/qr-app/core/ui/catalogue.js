function formatPrice(value){
  if (value === null || value === undefined || value === "") return "";
  if (typeof value === "number") return `${value.toLocaleString("vi-VN")}đ`;
  const text = String(value);
  if (/^\d+$/.test(text)) return `${Number(text).toLocaleString("vi-VN")}đ`;
  return text;
}

export function renderCatalogue(catalog, mount=document.body){
  const products = catalog.products || [];
  const banners = catalog.banners || [];
  const wrap = document.createElement("section");
  wrap.className = "section catalogue-core";
  wrap.innerHTML = `
    ${banners.length ? `<div class="catalogue-banners">${banners.map(b => `<img class="group-banner" src="${b.image_url || b.image || b.url || ""}" alt="banner" loading="lazy">`).join("")}</div>` : ""}
    <div class="menu-list">${products.map(p => `
      <button class="menu-card" data-id="${p.id || ""}" type="button">
        <span class="thumb"><img src="${p.image_url || p.image || ""}" alt="${p.name || ""}" loading="lazy"></span>
        <span class="info"><b>${p.name || ""}</b><span>${formatPrice(p.price)}</span></span>
        <span class="add">Thêm</span>
      </button>`).join("")}</div>`;
  mount.replaceChildren(wrap);
  return wrap;
}
