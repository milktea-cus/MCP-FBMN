let products=[];
let cart=JSON.parse(localStorage.getItem('chill_cart')||'[]');
let current=null;
let qty=1;

const money=v=>Number(v||0).toLocaleString('vi-VN')+'đ';
function save(){localStorage.setItem('chill_cart',JSON.stringify(cart));renderCart();}
function open(id){document.querySelector(id)?.classList.add('open');}
function close(el){el.closest('.modal')?.classList.remove('open');}
function count(){const n=cart.reduce((a,b)=>a+b.qty,0);const e=document.querySelector('#cartCount');if(e){e.textContent=n;e.style.display=n?'grid':'none';}}
function showProduct(p){current=p;qty=1;document.querySelector('#productName').textContent=p.name||'';document.querySelector('#productPrice').textContent=money(p.price);document.querySelector('#productImage').src=p.image_url||p.image||'';document.querySelector('#qty').textContent=qty;open('#productModal');}
function add(){if(!current)return;const x=cart.find(i=>i.id===current.id);if(x)x.qty+=qty;else cart.push({...current,qty});save();close(document.querySelector('#productModal'));}
function cartHtml(){const box=document.querySelector('#cartList');if(!box)return;box.innerHTML=cart.map((x,i)=>`<div class="cart-item"><img src="${x.image_url||x.image||''}"><div><b>${x.name}</b><br>${money(x.price)} x ${x.qty}</div><div class="line-actions"><button data-minus="${i}">-</button><button data-plus="${i}">+</button><button data-remove="${i}">×</button></div></div>`).join('');document.querySelector('#cartTotal').textContent=money(cart.reduce((a,b)=>a+Number(b.price||0)*b.qty,0));count();}
function order(){const text=cart.map(x=>`${x.name} x${x.qty} ${money(x.price)}`).join('\n');navigator.clipboard?.writeText(text);window.open('https://zalo.me/0702917377','_blank');}
export function initInteractions(catalog){
 products=catalog.products||[];
 document.addEventListener('click',e=>{
  const card=e.target.closest('.menu-card');if(card){const p=products.find(x=>String(x.id)===String(card.dataset.id));if(p)showProduct(p);}
  if(e.target.id==='addCart')add();
  if(e.target.id==='openCart'){cartHtml();open('#cartModal');}
  if(e.target.id==='placeOrder')order();
  if(e.target.id==='plus'){qty++;document.querySelector('#qty').textContent=qty;}
  if(e.target.id==='minus'){qty=Math.max(1,qty-1);document.querySelector('#qty').textContent=qty;}
  if(e.target.matches('[data-remove]')){cart.splice(Number(e.target.dataset.remove),1);save();}
  if(e.target.matches('[data-plus]')){cart[Number(e.target.dataset.plus)].qty++;save();}
  if(e.target.matches('[data-minus]')){cart[Number(e.target.dataset.minus)].qty=Math.max(1,cart[Number(e.target.dataset.minus)].qty-1);save();}
  if(e.target.id==='saveShop')localStorage.setItem('savedShop','1');
  if(e.target.matches('[data-close],.close'))close(e.target);
 });
 count();
}
