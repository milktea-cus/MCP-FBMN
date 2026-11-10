export function applyTheme(theme={}){
  const root=document.documentElement;
  const map={primary:'--brand-primary',background:'--brand-bg',surface:'--brand-surface',text:'--brand-text',radius:'--brand-radius',font:'--brand-font'};
  Object.entries(map).forEach(([key,varName])=>{
    if(theme[key]) root.style.setProperty(varName, theme[key]);
  });
  if(theme.font){
    document.body.style.fontFamily = `${theme.font}, system-ui, -apple-system, Segoe UI, sans-serif`;
  }
}
