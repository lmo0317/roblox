import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync(process.argv[2],'utf8');
const code=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
assert(!html.includes('id="rotate"'),'Normal portrait play must remain available');
function context(mode){
 const elements=new Map(),classes=new Set(),events={};
 const element=id=>{if(!elements.has(id))elements.set(id,{hidden:false,textContent:'',disabled:false,events:{},addEventListener(type,fn){this.events[type]=fn;},focus(){}});return elements.get(id);};
 const document={fullscreenElement:null,webkitFullscreenElement:null,body:{classList:{contains:x=>classes.has(x),add:x=>classes.add(x),remove:x=>classes.delete(x),toggle(x,value){if(value)classes.add(x);else classes.delete(x);}}},documentElement:{},getElementById:element,addEventListener(type,fn){events[type]=fn;}};
 let requested=0,started=0,locked=0,unlocked=0;
 const window={innerWidth:390,innerHeight:844,fetch:async()=>{},dispatchEvent(){},visualViewport:{addEventListener(){}}};
 if(mode==='standard'||mode==='lock-denied'){
  document.documentElement.requestFullscreen=async()=>{requested++;document.fullscreenElement=document.documentElement;events.fullscreenchange?.();};
  document.exitFullscreen=async()=>{document.fullscreenElement=null;events.fullscreenchange?.();};
 }else if(mode==='webkit'){
  document.documentElement.webkitRequestFullscreen=async()=>{requested++;document.webkitFullscreenElement=document.documentElement;events.webkitfullscreenchange?.();};
  document.webkitExitFullscreen=async()=>{document.webkitFullscreenElement=null;events.webkitfullscreenchange?.();};
 }else if(mode==='denied')document.documentElement.requestFullscreen=async()=>{throw new Error('not allowed');};
 class Engine{static getMissingFeatures(){return [];}async startGame(){started++;}}
 const orientation=mode==='webkit'?{}:{lock:async(value)=>{assert.equal(value,'landscape');locked++;if(mode!=='standard')throw new Error('unsupported');window.innerWidth=844;window.innerHeight=390;},unlock:()=>unlocked++};
 const sandbox={window,document,location:new URL('https://game.example/play/game.html'),URL,Response,DecompressionStream,Engine,Event,setTimeout:()=>1,clearTimeout(){},screen:{orientation}};
 vm.createContext(sandbox);vm.runInContext(code,sandbox);
 return {sandbox,window,document,element,classes,events,counts:()=>({requested,started,locked,unlocked})};
}
const normal=context('standard');
await normal.element('start').events.click();
assert.equal(normal.counts().locked,0,'Normal play must not lock orientation');
assert.equal(normal.counts().requested,0,'Normal play must not enter fullscreen');
for(const mode of ['standard','webkit','unsupported','denied','lock-denied']){
 const ctx=context(mode);
 await ctx.element('startFull').events.click();
 assert.equal(ctx.counts().started,1,mode+': game should start');
 assert.equal(ctx.element('cover').hidden,true,mode+': canvas shown');
 if(mode==='standard'){
  assert.equal(ctx.counts().locked,1,'Native landscape orientation requested');
  assert(!ctx.classes.has('virtual-landscape'),'No CSS rotation after native rotation');
 }else{
  assert(ctx.classes.has('virtual-landscape'),mode+': CSS landscape fallback');
  assert.equal(ctx.sandbox.EGG_LANDSCAPE_ROTATED,true,'Input adapter enabled');
  ctx.window.innerWidth=844;ctx.window.innerHeight=390;
  vm.runInContext('resizeGame()',ctx.sandbox);
  assert(!ctx.classes.has('virtual-landscape'),'Avoid double rotation on device rotate');
  ctx.window.innerWidth=390;ctx.window.innerHeight=844;
  vm.runInContext('resizeGame()',ctx.sandbox);
  assert(ctx.classes.has('virtual-landscape'),'Restore fallback when device is portrait');
 }
 await vm.runInContext('toggleFullscreen()',ctx.sandbox);
 assert(!ctx.document.fullscreenElement&&!ctx.document.webkitFullscreenElement&&!ctx.classes.has('immersive'),mode+': exit fullscreen');
 assert(!ctx.classes.has('virtual-landscape')&&!ctx.sandbox.EGG_LANDSCAPE_ROTATED,mode+': restore portrait input');
 console.log('LANDSCAPE_FULLSCREEN_PASS',mode);
}
const escape=context('standard');await escape.element('startFull').events.click();
escape.document.fullscreenElement=null;escape.events.fullscreenchange();
assert.equal(escape.counts().unlocked,1,'System fullscreen exit unlocks orientation');
assert.equal(escape.sandbox.EGG_LANDSCAPE_ROTATED,false);
if(process.argv[3]){
 const engine=fs.readFileSync(process.argv[3],'utf8');
 const method=engine.match(/computePosition:(function\(evt,rect\)\{[\s\S]+?\}),onKeyEvent:/)[1];
 const sandbox={GodotConfig:{canvas:{width:1688,height:780}},EGG_LANDSCAPE_ROTATED:true};
 vm.createContext(sandbox);vm.runInContext('this.mapPoint='+method,sandbox);
 const rect={x:0,y:0,top:0,left:0,right:390,width:390,height:844};
 for(const [x,y,ex,ey] of [[390,0,0,0],[390,844,1688,0],[0,844,1688,780],[0,0,0,780],[195,422,844,390]]){
  const point=sandbox.mapPoint({clientX:x,clientY:y},rect);
  assert(Math.abs(point[0]-ex)<.001&&Math.abs(point[1]-ey)<.001,'Rotated touch coordinates');
 }
 sandbox.EGG_LANDSCAPE_ROTATED=false;
 const p=sandbox.mapPoint({clientX:195,clientY:422},rect);
 assert.equal(p[0],844);assert.equal(p[1],390);
 console.log('ROTATED_TOUCH_PASS corners, center and normal input');
}
