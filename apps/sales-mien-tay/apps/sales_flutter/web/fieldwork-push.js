/* Web Push bridge: same-origin, no business data or tokens stored here. */
(function(){
  const supported=()=>('serviceWorker' in navigator)&&('PushManager' in window)&&
    ('Notification' in window)&&window.isSecureContext;
  const decode=(s)=>{
    const input=s.padEnd(Math.ceil(s.length/4)*4,'=').replace(/-/g,'+').replace(/_/g,'/');
    return Uint8Array.from(atob(input),c=>c.charCodeAt(0));
  };
  async function worker(){
    await navigator.serviceWorker.register('/filed-sw.js');
    return navigator.serviceWorker.ready;
  }
  window.FieldWorkPush={
    supported,
    async subscribed(){
      if(!supported())return false;
      const reg=await worker();return !!(await reg.pushManager.getSubscription());
    },
    async existing(){
      if(!supported())return '';
      const reg=await worker(),subscription=await reg.pushManager.getSubscription();
      return subscription?JSON.stringify(subscription.toJSON()):'';
    },
    async enable(key){
      if(!supported())throw Error('Thiết bị không hỗ trợ Web Push.');
      // The permission request starts within the user's direct click.
      const permission=await Notification.requestPermission();
      if(permission!=='granted')throw Error('Chưa cấp quyền thông báo.');
      const reg=await worker();
      let subscription=await reg.pushManager.getSubscription();
      if(!subscription)subscription=await reg.pushManager.subscribe({
        userVisibleOnly:true,applicationServerKey:decode(key)});
      return JSON.stringify(subscription.toJSON());
    },
    async disable(){
      if(!supported())return '';
      const reg=await worker(),subscription=await reg.pushManager.getSubscription();
      if(!subscription)return '';
      const data=JSON.stringify(subscription.toJSON());
      await subscription.unsubscribe();return data;
    },
    badge(count){
      if(!('setAppBadge' in navigator))return;
      const promise=count>0?navigator.setAppBadge(count):navigator.clearAppBadge();
      if(promise&&promise.catch)promise.catch(()=>{});
    }
  };
})();
