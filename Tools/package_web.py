from pathlib import Path
import gzip,json,re,shutil,sys
root=Path(sys.argv[1]).resolve();play=root/'play'
original=(play/'game.html').read_text();config=json.loads(re.search(r'const GODOT_CONFIG = (.*?);',original).group(1));config['ensureCrossOriginIsolationHeaders']=False
wasm=(play/'game.wasm').read_bytes();compressed=gzip.compress(wasm,compresslevel=9,mtime=0);(play/'game.wasm.gz').write_bytes(compressed);(play/'game.wasm').unlink()
assert gzip.decompress(compressed)==wasm
print('Web engine compressed:',len(wasm),'->',len(compressed))
html='''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="theme-color" content="#112d45"><title>Egg Dash · 바로 플레이</title><meta name="description" content="설치 없이 즐기는 3D 펫 수집 게임. 알을 구하고 나만의 펫 정원을 키워보세요."><link rel="icon" href="game.icon.png"><style>
*{box-sizing:border-box}html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#112d45;color:#f4f8ef;font-family:system-ui,-apple-system,sans-serif}#canvas{display:block;width:100%;height:100%;outline:0;touch-action:none}#cover{position:fixed;inset:0;display:grid;place-items:center;background:radial-gradient(ellipse at 50% 20%,#245e74,#112d45 70%);z-index:5;padding:20px}.card{max-width:500px;text-align:center}h1{font-size:clamp(38px,7vw,64px);letter-spacing:-2px;margin:10px 0;color:#f5ffc9}p{line-height:1.7;color:#c7ddd9}.egg{width:90px;height:90px;image-rendering:auto;border-radius:23px;box-shadow:0 16px 40px #071d36}button{font:700 18px system-ui;color:#163746;background:#b9ed5b;border:0;border-radius:14px;padding:17px 45px;cursor:pointer;min-height:48px}button:hover{background:#d0ff80}button:disabled{opacity:.55;cursor:wait}progress{width:100%;height:12px;accent-color:#b9ed5b;margin-top:20px}small{display:block;font-size:13px;line-height:1.7;color:#9dbdc7;margin-top:22px}#status{min-height:27px;margin-top:15px}#detail{font:12px ui-monospace,monospace;color:#e9c5b0;white-space:pre-wrap;max-height:140px;overflow:auto}#fullscreen{position:fixed;top:max(10px,env(safe-area-inset-top));left:50%;transform:translateX(-50%);padding:8px 14px;min-height:36px;font-size:12px;z-index:3;background:#173b50b8;color:white;border:1px solid #ffffff55;border-radius:20px}#rotate{display:none;position:fixed;inset:0;z-index:9;background:#112d45;place-items:center;text-align:center;padding:30px}@media(orientation:portrait) and (pointer:coarse){#rotate{display:grid}}[hidden]{display:none!important}
</style></head><body>
<canvas id="canvas" tabindex="0" aria-label="Egg Dash 게임 화면">이 브라우저에서는 게임 화면을 표시할 수 없습니다.</canvas>
<button id="fullscreen" hidden aria-label="전체 화면으로 플레이">⛶ 전체화면</button>
<div id="cover"><div class="card"><img class="egg" src="game.icon.png" alt="파란 무늬의 알"><h1>EGG DASH</h1><p>알을 구하고, 펫을 부화시키고,<br>나만의 정원을 키워보세요.</p><button id="start">게임 시작</button><progress id="progress" hidden></progress><div id="status" role="status" aria-live="polite"></div><pre id="detail" hidden></pre><small>PC · WASD 이동 / 마우스 우클릭 시점 / E 상호작용<br>휴대폰 · 왼쪽 이동 패드 / 오른쪽 드래그 / USE 버튼</small></div></div>
<div id="rotate"><div><div style="font-size:48px">↻</div><h2>휴대폰을 가로로 돌려주세요</h2><p>가로 화면에서 더 편하게 플레이할 수 있어요.</p></div></div>
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
start.addEventListener('click',async()=>{
 if(starting)return;starting=true;start.disabled=true;status.textContent='게임을 불러오고 있어요…';progress.hidden=false;
 try{
  const missing=Engine.getMissingFeatures({threads:false});if(missing.length)throw new Error('이 브라우저에서 지원하지 않는 기능: '+missing.join(', '));
  const engine=new Engine(CONFIG);
  await engine.startGame({onProgress:(current,total)=>{if(total>0){progress.max=total;progress.value=current;status.textContent='불러오는 중 '+Math.min(100,Math.round(current/total*100))+'%';}}});
  document.getElementById('cover').hidden=true;full.hidden=false;document.getElementById('canvas').focus();
 }catch(error){starting=false;start.disabled=false;progress.hidden=true;status.textContent='게임을 시작하지 못했어요. 다시 시도해주세요.';const detail=document.getElementById('detail');detail.hidden=false;detail.textContent=String(error);}
});
full.addEventListener('click',async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else{await document.documentElement.requestFullscreen();if(screen.orientation?.lock)await screen.orientation.lock('landscape').catch(()=>{});}}catch(error){full.textContent='브라우저 메뉴에서 전체화면';}});
</script></body></html>'''
(play/'game.html').write_text(html.replace('__CONFIG__',json.dumps(config,separators=(',',':'))))
(root/'index.html').write_text('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Egg Dash</title><meta http-equiv="refresh" content="0;url=play/game.html"><script>location.replace("play/game.html"+location.search+location.hash)</script><a href="play/game.html">게임 시작</a></html>')
for f in root.rglob('*'):
 if f.is_file(): assert f.stat().st_size<25*1024*1024,(f,f.stat().st_size)
print('Static asset size checks passed')
