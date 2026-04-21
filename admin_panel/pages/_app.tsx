import type { AppProps } from 'next/app';
import { useRouter } from 'next/router';
import { useEffect } from 'react';
import '../styles/globals.css';
const PUBLIC = ['/login'];
const NAV = [
  {g:'Overview', items:[{href:'/dashboard',icon:'📊',label:'Dashboard'},{href:'/analytics',icon:'📈',label:'Analytics'},{href:'/revenue',icon:'💰',label:'Revenue'}]},
  {g:"Content", items:[{href:"/template-builder",icon:"🔨",label:"Builder"},{href:"/templates",icon:'🎨',label:'Templates'},{href:'/assets',icon:'🗂️',label:'Assets'}]},
  {g:'Users',    items:[{href:'/users',icon:'👥',label:'Users'},{href:'/moderation',icon:'🛡️',label:'Moderation'}]},
  {g:'Ops',      items:[{href:'/exports',icon:'📤',label:'Export Queue'},{href:'/push-notifications',icon:'🔔',label:'Push Notifications'}]},
  {g:'Platform', items:[{href:'/feature-flags',icon:'🚩',label:'Feature Flags'},{href:'/ab-tests',icon:'🧪',label:'A/B Tests'},{href:'/staff',icon:'🔐',label:'Staff'}]},
];
function Sidebar(){
  const router=useRouter();
  return(
    <div style={{width:210,minHeight:'100vh',background:'#16161d',borderRight:'1px solid #2a2a38',padding:'14px 10px',flexShrink:0,display:'flex',flexDirection:'column',overflowY:'auto'}}>
      <div style={{display:'flex',alignItems:'center',gap:10,padding:'8px 10px',marginBottom:16}}>
        <div style={{width:34,height:34,background:'linear-gradient(135deg,#7c6ef7,#4ecdc4)',borderRadius:9,display:'flex',alignItems:'center',justifyContent:'center',fontSize:17}}>🎬</div>
        <div><div style={{color:'#e8e6ff',fontWeight:700,fontSize:13}}>Admin Panel</div><div style={{color:'#5c5a78',fontSize:10}}>Video Editor Pro</div></div>
      </div>
      <nav style={{flex:1}}>
        {NAV.map(s=>(
          <div key={s.g} style={{marginBottom:10}}>
            <div style={{color:'#5c5a78',fontSize:9,fontWeight:700,textTransform:'uppercase',letterSpacing:1,padding:'4px 10px'}}>{s.g}</div>
            {s.items.map(i=>{
              const a=router.pathname.startsWith(i.href);
              return(<a key={i.href} href={i.href} style={{display:'flex',alignItems:'center',gap:9,padding:'8px 10px',borderRadius:8,marginBottom:1,textDecoration:'none',background:a?'#7c6ef720':'transparent',color:a?'#7c6ef7':'#9d9bb8',fontWeight:a?600:400,fontSize:13,borderLeft:a?'2px solid #7c6ef7':'2px solid transparent'}}>
                <span style={{fontSize:14}}>{i.icon}</span><span>{i.label}</span>
              </a>);
            })}
          </div>
        ))}
      </nav>
      <div style={{borderTop:'1px solid #2a2a38',paddingTop:8,marginTop:6}}><div style={{color:'#3a3a50',fontSize:10,textAlign:'center'}}>v1.0.0</div></div>
    </div>
  );
}
export default function App({Component,pageProps}:AppProps){
  const router=useRouter();
  const isPublic=PUBLIC.some(p=>router.pathname.startsWith(p))||router.pathname==='/';
  useEffect(()=>{if(!isPublic&&!localStorage.getItem('admin_token'))router.push('/login');},[router.pathname]);
  if(isPublic)return<Component {...pageProps}/>;
  return(<div style={{display:'flex',minHeight:'100vh',background:'#0f0f13'}}><Sidebar/><main style={{flex:1,overflow:'auto',minWidth:0}}><Component {...pageProps}/></main></div>);
}
