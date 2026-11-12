import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync(process.argv[2],'utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
assert(!html.includes('id="rotate"'),'Portrait must never be blocked');
assert(!code.includes("orientation.lock('landscape')"),'Do not force landscape');
function context(mode){
 const elements=new Map(),classes=new Set();
 const element=id=>{if(!elements.has(id))elements.set(id,{hidden:false,textContent:'',disabled:false,events:{},addEventListener(type,fn){this.events[type]=fn;},focus(){}});return elements.get(id);};
 const document={fullscreenElement:null,webkitFullscreenElement:null,body:{classList:{contains:x=>classes.has(x),add:x=>classes.add(x),remove:x=>classes.delete(x)}},documentElement:{},getElementById:element,addEventListener(){}};
 let requested=0,started=0,locked=0;
 if(mode==='standard'){
  document.documentElement.requestFullscreen=async()=>{requested++;document.fullscreenElement=document.documentElement;};
  document.exitFullscreen=async()=>{document.fullscreenElement=null;};
 }else if(mode==='webkit'){
  document.documentElement.webkitRequestFullscreen=async()=>{requested++;document.webkitFullscreenElement=document.documentElement;};
  document.webkitExitFullscreen=async()=>{document.webkitFullscreenElement=null;};
 }else if(mode==='denied')document.documentElement.requestFullscreen=async()=>{throw new Error('not allowed');};
 class Engine{static getMissingFeatures(){return [];}async startGame(){started++;}}
 const window={fetch:async()=>{},dispatchEvent(){},visualViewport:{addEventListener(){}}};
 const sandbox={window,document,location:new URL('https://game.example/play/game.html'),URL,Response,DecompressionStream,Engine,Event,setTimeout:()=>1,clearTimeout(){},screen:{orientation:{lock:()=>{locked++;}}}};
 vm.createContext(sandbox);vm.runInContext(code,sandbox);
 return {sandbox,document,element,classes,counts:()=>({requested,started,locked})};
}
for(const mode of ['standard','webkit','unsupported','denied']){
 const ctx=context(mode);
 await ctx.element('startFull').events.click();
 assert.equal(ctx.counts().started,1,mode+': game should start');
 assert.equal(ctx.counts().locked,0,mode+': orientation must be preserved');
 assert.equal(ctx.element('cover').hidden,true,mode+': game canvas should be shown');
 if(['unsupported','denied'].includes(mode))assert(ctx.classes.has('immersive'),mode+': fill-screen fallback');
 else assert(ctx.document.fullscreenElement||ctx.document.webkitFullscreenElement,mode+': native fullscreen');
 await vm.runInContext('toggleFullscreen()',ctx.sandbox);
 assert(!ctx.document.fullscreenElement&&!ctx.document.webkitFullscreenElement&&!ctx.classes.has('immersive'),mode+': exit fullscreen');
 console.log('FULLSCREEN_PASS',mode);
}
