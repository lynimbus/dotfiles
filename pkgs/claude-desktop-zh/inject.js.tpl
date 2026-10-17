(()=>{try{
const W=window;if(!W.__claudeZhDom)W.__claudeZhDom={orig:new WeakMap(),obs:null,on:false,lang:null};
const S=W.__claudeZhDom;
const LOCALES=__LOCALES__;
const M=__MAP__;
const norm=s=>(s||"").replace(/\s+/g," ").trim();
const tr=s=>{const q=norm(s);if(!q||q.length>1000)return null;return M[q]!==void 0?M[q]:null};
const skip=new Set(['SCRIPT','STYLE','CODE','PRE','TEXTAREA']);
const chosen=()=>{try{return (localStorage.getItem('spa:locale')||'').toLowerCase()}catch(e){return ''}};
const active=()=>LOCALES.some(l=>l.toLowerCase()===chosen());
const walk=n=>{if(n.nodeType===3){const p=n.parentElement;
if(!p||skip.has(p.tagName))return;
const t=tr(n.nodeValue);if(t===null||t===n.nodeValue)return;
if(!S.orig.has(n))S.orig.set(n,n.nodeValue);n.nodeValue=t;return}
for(const c of n.childNodes)walk(c)};
const restore=()=>{try{document.body&&(()=>{const it=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
let x;while(x=it.nextNode()){if(S.orig.has(x)){x.nodeValue=S.orig.get(x);S.orig.delete(x)}}})()}catch(e){}};
const enable=()=>{if(S.on)return;S.on=true;
if(!S.lang)S.lang=document.documentElement&&document.documentElement.getAttribute('lang');
document.documentElement&&document.documentElement.setAttribute("lang","zh-CN");
try{walk(document.body)}catch(e){}
S.obs=new MutationObserver(ms=>{if(!active())return;for(const m of ms){
for(const n of m.addedNodes)if(n.nodeType===1)walk(n);
if(m.type==='characterData')walk(m.target.parentElement||m.target)}});
S.obs.observe(document.body,{childList:true,subtree:true,characterData:true})};
const disable=()=>{if(!S.on)return;S.on=false;
if(S.obs){S.obs.disconnect();S.obs=null}restore();
try{if(document.documentElement){if(S.lang===null)document.documentElement.removeAttribute('lang');
else document.documentElement.setAttribute('lang',S.lang)}S.lang=null}catch(e){}};
const sync=()=>{if(active())enable();else disable()};
if(!W.__claudeZhLocaleHook){W.__claudeZhLocaleHook=1;
const B=W['claude.hybrid']&&W['claude.hybrid'].DesktopIntl;
if(B&&B.onLocaleChanged)B.onLocaleChanged(loc=>{try{localStorage.setItem('spa:locale',loc)}catch(e){};sync()});
if(B&&B.getInitialLocale)B.getInitialLocale().then(r=>{
const loc=r&&r.locale;if(!loc)return;
try{localStorage.setItem('spa:locale',loc)}catch(e){};sync()}).catch(()=>sync());
W.addEventListener('storage',e=>{if(e.key==='spa:locale')sync()});
setInterval(sync,1000)}
sync();
}catch(e){}})();
