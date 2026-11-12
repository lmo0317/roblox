from pathlib import Path
import gzip,json,re,shutil,sys
from web_landscape_engine import patch_engine
root=Path(sys.argv[1]).resolve();play=root/'play'
original=(play/'game.html').read_text();config=json.loads(re.search(r'const GODOT_CONFIG = (.*?);',original).group(1));config['ensureCrossOriginIsolationHeaders']=False
wasm=(play/'game.wasm').read_bytes();compressed=gzip.compress(wasm,compresslevel=9,mtime=0);(play/'game.wasm.gz').write_bytes(compressed);(play/'game.wasm').unlink()
assert gzip.decompress(compressed)==wasm
print('Web engine compressed:',len(wasm),'->',len(compressed))
html='''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#112d45"><title>Egg Dash · 바로 플레이</title><meta name="description" content="설치 없이 즐기는 3D 펫 수집 게임. 알을 구하고 나만의 펫 정원을 키워보세요."><link rel="icon" href="game.icon.png"><style>
*{box-sizing:border-box}html,body{width:100%;height:100%;height:100dvh;overscroll-behavior:none;margin:0;overflow:hidden;background:#112d45;color:#f4f8ef;font-family:system-ui,-apple-system,sans-serif}#canvas{display:block;width:100%;height:100%;height:100dvh;outline:0;touch-action:none}#cover{position:fixed;inset:0;display:grid;place-items:center;background:radial-gradient(ellipse at 50% 20%,#245e74,#112d45 70%);z-index:5;padding:20px}.card{max-width:500px;text-align:center}h1{font-size:clamp(38px,7vw,64px);letter-spacing:-2px;margin:10px 0;color:#f5ffc9}p{line-height:1.7;color:#c7ddd9}.egg{width:90px;height:90px;image-rendering:auto;border-radius:23px;box-shadow:0 16px 40px #071d36}button{font:700 18px system-ui;color:#163746;background:#b9ed5b;border:0;border-radius:14px;padding:17px 45px;cursor:pointer;min-height:48px}button:hover{background:#d0ff80}button:disabled{opacity:.55;cursor:wait}progress{width:100%;height:12px;accent-color:#b9ed5b;margin-top:20px}small{display:block;font-size:13px;line-height:1.7;color:#9dbdc7;margin-top:22px}#status{min-height:27px;margin-top:15px}#detail{font:12px ui-monospace,monospace;color:#e9c5b0;white-space:pre-wrap;max-height:140px;overflow:auto}#fullscreen{position:fixed;top:max(10px,env(safe-area-inset-top));left:50%;transform:translateX(-50%);padding:8px 14px;min-height:36px;font-size:12px;z-index:3;background:#173b50b8;color:white;border:1px solid #ffffff55;border-radius:20px}body.virtual-landscape #canvas,body.immersive.virtual-landscape #canvas{position:fixed;left:50%;top:50%;inset:auto;transform:translate(-50%,-50%) rotate(90deg);width:100dvh!important;height:100dvw!important}#startFull{margin-top:10px;background:transparent;color:#d9f5b7;border:1px solid #93b378;padding:12px 26px;font-size:15px}#toast{position:fixed;left:50%;bottom:18%;transform:translateX(-50%);z-index:8;max-width:90%;width:max-content;background:#112d45ed;padding:12px 18px;border-radius:12px;text-align:center;font-size:13px;color:white}body.immersive #canvas{position:fixed;inset:0;width:100dvw;height:100dvh}[hidden]{display:none!important}
</style></head><body>
<canvas id="canvas" tabindex="0" aria-label="Egg Dash 게임 화면">이 브라우저에서는 게임 화면을 표시할 수 없습니다.</canvas>
<button id="fullscreen" hidden aria-label="전체 화면으로 플레이">⛶ 전체화면</button>
<div id="cover"><div class="card"><img class="egg" src="game.icon.png" alt="파란 무늬의 알"><h1>EGG DASH</h1><p>알을 구하고, 펫을 부화시키고,<br>나만의 정원을 키워보세요.</p><button id="start">게임 시작</button><br><button id="startFull">가로 전체화면으로 시작</button><progress id="progress" hidden></progress><div id="status" role="status" aria-live="polite"></div><pre id="detail" hidden></pre><small>PC · WASD 이동 / 마우스 우클릭 시점 / E 상호작용<br>휴대폰 · 왼쪽 이동 패드 / 오른쪽 드래그 / USE 버튼</small></div></div>
<div id="toast" role="status" hidden></div>
<script src="game.js"></script><script>
const CONFIG=__CONFIG__;
// Serve the compressed engine within static-host asset size limits.
// Godot still receives a streaming application/wasm response.
const nativeFetch=window.fetch.bind(window);
window.fetch=async function(input,options){
 const path=new URL(typeof input==='string'?input:input instanceof URL?input.href:input.url,location.href);
 if(path.origin===location.origin&&path.pathname.endsWith('/game.wasm')){
  const response=await nativeFetch(new URL('game.wasm.gz',location.href),options);
  if(!response.ok)throw new Error('게임 엔진 다운로드 실패 ('+response.status+')');
  if(!('DecompressionStream' in window))throw new Error('브라우저를 최신 버전으로 업데이트해주세요.');
  return new Response(response.body.pipeThrough(new DecompressionStream('gzip')),{headers:{'Content-Type':'application/wasm','Content-Length':String(CONFIG.fileSizes['game.wasm'])}});
 }
 return nativeFetch(input,options);
};
const start=document.getElementById('start'),status=document.getElementById('status'),progress=document.getElementById('progress'),full=document.getElementById('fullscreen');
let starting=false;
async function launchGame(){
 if(starting)return;starting=true;start.disabled=true;status.textContent='게임을 불러오고 있어요…';progress.hidden=false;
 try{
  const missing=Engine.getMissingFeatures({threads:false});if(missing.length)throw new Error('이 브라우저에서 지원하지 않는 기능: '+missing.join(', '));
  const engine=new Engine(CONFIG);
  await engine.startGame({onProgress:(current,total)=>{if(total>0){progress.max=total;progress.value=current;status.textContent='불러오는 중 '+Math.min(100,Math.round(current/total*100))+'%';}}});
  document.getElementById('cover').hidden=true;full.hidden=false;document.getElementById('canvas').focus();
  full.textContent=fullscreenLabel();
 }catch(error){starting=false;start.disabled=false;progress.hidden=true;status.textContent='게임을 시작하지 못했어요. 다시 시도해주세요.';const detail=document.getElementById('detail');detail.hidden=false;detail.textContent=String(error);}
}
let toastTimer;
function showNotice(text){const toast=document.getElementById('toast');toast.textContent=text;toast.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.hidden=true,4500);}
function fullscreenElement(){return document.fullscreenElement||document.webkitFullscreenElement;}
function fullscreenLabel(){return fullscreenElement()||document.body.classList.contains('immersive')?'⛶ 전체화면 해제':'⛶ 전체화면';}
let landscapeRequested=false;
function updateLandscapeLayout(){
 const rotate=landscapeRequested&&window.innerHeight>window.innerWidth;
 globalThis.EGG_LANDSCAPE_ROTATED=rotate;
 document.body.classList.toggle('virtual-landscape',rotate);
}
function resizeGame(){updateLandscapeLayout();window.dispatchEvent(new Event('resize'));full.textContent=fullscreenLabel();}
function releaseLandscape(){
 const wasRequested=landscapeRequested;landscapeRequested=false;
 if(wasRequested){try{screen.orientation?.unlock?.();}catch(error){}}
 updateLandscapeLayout();
}
async function lockLandscape(){
 try{if(screen.orientation?.lock)await screen.orientation.lock('landscape');}catch(error){}
 // Use a rotated canvas and matching input coordinates when native rotation is unavailable.
 updateLandscapeLayout();
}
async function enterFullscreen(){
 const root=document.documentElement;
 landscapeRequested=true;
 try{
  if(root.requestFullscreen)await root.requestFullscreen({navigationUI:'hide'});
  else if(root.webkitRequestFullscreen)await root.webkitRequestFullscreen();
  else throw new Error('Fullscreen API unavailable');
  document.body.classList.remove('immersive');
 }catch(error){document.body.classList.add('immersive');showNotice('화면 채우기 모드입니다. 이 브라우저에서는 주소창 숨기기가 지원되지 않을 수 있어요.');}
 await lockLandscape();
 resizeGame();
}
async function toggleFullscreen(){
 if(fullscreenElement()){
  if(document.exitFullscreen)await document.exitFullscreen();
  else if(document.webkitExitFullscreen)await document.webkitExitFullscreen();
 }else if(document.body.classList.contains('immersive'))document.body.classList.remove('immersive');
 else{await enterFullscreen();return;}
 releaseLandscape();
 resizeGame();
}
start.addEventListener('click',launchGame);
document.getElementById('startFull').addEventListener('click',async()=>{await enterFullscreen();await launchGame();});
full.addEventListener('click',()=>toggleFullscreen().catch(()=>showNotice('전체화면 전환을 다시 눌러주세요.')));
function handleFullscreenChange(){if(!fullscreenElement()&&!document.body.classList.contains('immersive'))releaseLandscape();resizeGame();}
document.addEventListener('fullscreenchange',handleFullscreenChange);
document.addEventListener('webkitfullscreenchange',handleFullscreenChange);
window.visualViewport?.addEventListener('resize',resizeGame);
</script></body></html>'''
patch_engine(play/'game.js')
(play/'game.html').write_text(html.replace('__CONFIG__',json.dumps(config,separators=(',',':'))))
(root/'index.html').write_text('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Egg Dash</title><meta http-equiv="refresh" content="0;url=play/game.html"><script>location.replace("play/game.html"+location.search+location.hash)</script><a href="play/game.html">게임 시작</a></html>')
for f in root.rglob('*'):
 if f.is_file(): assert f.stat().st_size<25*1024*1024,(f,f.stat().st_size)
print('Static asset size checks passed')
