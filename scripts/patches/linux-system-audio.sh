#!/usr/bin/env bash
#===============================================================================
# linux-system-audio.sh -- enable native PipeWire/PulseAudio system audio
# capture (--capture-system-audio) on Linux in the Wispr Flow main bundle
# (.webpack/main/index.js).
#
# WHY THIS PATCH EXISTS
# ---------------------
# Wispr Flow's MeetingRecorder spawns the native helper with
# `["--capture-system-audio"]`, reading 1,304-byte WAF2 frames (16 kHz mono
# s16le PCM) from stdout and `endpoint_opened` from stderr. Upstream gates
# this native system capture path on `f.H8` (`"win32" === process.platform`)
# and passes an empty environment (`env:{}`) to `spawn()`.
#
# On Linux:
#   1. The helper needs `XDG_RUNTIME_DIR` / `PULSE_SERVER` from `process.env`
#      so `libpulse-simple.so.0` can connect to PipeWire's `@DEFAULT_MONITOR@`.
#   2. `H(e,t)` and `V(e)` in the native system audio module must take the
#      native helper branch on Linux (`f.H8 || "linux" === process.platform`)
#      instead of falling back to the unimplemented renderer capture IPC.
#
# Usage: linux-system-audio.sh <path-to-.webpack/main/index.js>
#===============================================================================
set -euo pipefail

# shellcheck source=scripts/patches/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
patch_begin "WISPR_LINUX_SYSTEM_AUDIO" "${1:-}"

python3 - "$BUNDLE" "$MARKER" <<'PY'
import io, re, sys

path, marker = sys.argv[1], sys.argv[2]
with io.open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
	src = f.read()

# 1. Pass process.env into the --capture-system-audio spawn options so PipeWire/PulseAudio socket paths resolve.
spawn_anchor = re.compile(
	r'\["--capture-system-audio"\],\{windowsHide:!0,stdio:"pipe",env:\{\}\}'
)
ms1 = list(spawn_anchor.finditer(src))
if len(ms1) != 1:
	sys.exit(f"ERROR: expected 1 --capture-system-audio spawn anchor, found {len(ms1)}.")

m1 = ms1[0]
spawn_repl = f'["--capture-system-audio"],{{windowsHide:!0,stdio:"pipe",env:/*{marker}*/process.env}}'
src = src[:m1.start()] + spawn_repl + src[m1.end():]

# 2. Widen the native capture start/stop platform gate in the same module to include Linux.
ID = r'[\w$]+'
gate_anchor = re.compile(
	r'function (?P<H>' + ID + r')\((?P<e1>' + ID + r'),(?P<t1>' + ID + r')\)\{if\((?P<flag>' + ID + r'\.H8)\)\{if\(!(?P<M>' + ID + r')\|\|!(?P<U>' + ID + r')\)throw new Error\("Native capture handlers must be registered before capture starts"\);'
	r'(?P<body>.{200,4000}?)'
	r'function (?P<V>' + ID + r')\((?P<e2>' + ID + r')\)\{return (?P=flag)\?'
)
ms2 = list(gate_anchor.finditer(src))
if len(ms2) != 1:
	sys.exit(f"ERROR: expected 1 native system capture H/V gate anchor, found {len(ms2)}.")

m2 = ms2[0]
flag = m2['flag']
widen = f'({flag}||"linux"===process.platform)'
repl2 = (
	f'function {m2["H"]}({m2["e1"]},{m2["t1"]}){{if({widen}){{if(!{m2["M"]}||!{m2["U"]})throw new Error("Native capture handlers must be registered before capture starts");'
	+ m2['body']
	+ f'function {m2["V"]}({m2["e2"]}){{return {widen}?'
)
src = src[:m2.start()] + repl2 + src[m2.end():]
src = src.replace('isSystemAudio:"linux"!==process.platform&&!t', 'isSystemAudio:!t')

# 3. Inject Notetaker Audio Input selector (System + Mic, System Only, Mic Only),
# early second-instance Hub readiness reveal, and XWayland Status Pill shape/animation handler.
shim = r'''/*WISPR_LINUX_NOTETAKER_INPUT_AND_PILL*/;(function(){if("linux"!==process.platform)return;try{const{app:e,BrowserWindow:t,ipcMain:n,Menu:r}=require("electron"),i=require("fs"),s=require("path"),o=require("os");if(!e||!t||!n||!r)return;let A=!1;const y=new Set,v=e=>!e.isDestroyed()&&["Flow Hub","Wispr Flow"].includes(e.getTitle()),E=e=>{A=!1;try{e.isDestroyed()||(e.isMinimized()&&e.restore(),e.show(),e.focus())}catch{}},S=e=>{if(e.isDestroyed()||e.__wisprHubGuarded)return;e.__wisprHubGuarded=!0;const t=e.webContents.id;e.once("ready-to-show",()=>{y.add(t),A&&v(e)&&E(e)}),e.once("show",()=>{y.add(t)}),e.once("closed",()=>{y.delete(t)})};e.on("second-instance",(e,n)=>{if(!Array.isArray(n)||n.includes("--quit-app")||n.some(e=>e.startsWith("--squirrel-")))return;const r=t.getAllWindows().find(v);r&&y.has(r.webContents.id)||((A=!0),r&&S(r))}),e.on("browser-window-created",(e,t)=>{v(t)&&S(t)});for(const e of t.getAllWindows())v(e)&&S(e);const a=s.join(process.env.XDG_CONFIG_HOME||s.join(o.homedir(),".config"),"Wispr Flow"),c=s.join(a,"notetaker-input-mode.json"),l=()=>{try{const e=JSON.parse(i.readFileSync(c,"utf8"));if(["both","system_only","mic_only"].includes(e.mode))return e.mode}catch{}return"both"},u=e=>{try{i.mkdirSync(a,{recursive:!0}),i.writeFileSync(c,JSON.stringify({mode:e,updatedAt:Date.now()},null,2))}catch{}};i.existsSync(c)||u("both");const d=n.on.bind(n);n.on=function(e,t){return"media:meetingMicChunk"===e?d(e,function(e,n){if(n&&n.pcmData&&"system_only"===l())try{new Uint8Array(n.pcmData instanceof ArrayBuffer?n.pcmData:n.pcmData.buffer||n.pcmData).fill(0)}catch{}return t.call(this,e,n)}):d(e,t)};const p=r.buildFromTemplate.bind(r);r.buildFromTemplate=function(e){if(Array.isArray(e)&&e.some(e=>e&&"quit"===e.role)&&!e.some(e=>e&&"Notetaker Audio Input"===e.label)){const t=l(),n={label:"Notetaker Audio Input",submenu:[{label:"System Audio + Microphone (Both)",type:"radio",checked:"both"===t,click:()=>u("both")},{label:"System Audio Only (Desktop Sound)",type:"radio",checked:"system_only"===t,click:()=>u("system_only")},{label:"Microphone Only",type:"radio",checked:"mic_only"===t,click:()=>u("mic_only")}]},r=e.findIndex(e=>e&&"quit"===e.role),i=r>0?r:e.length;e=[...e.slice(0,i),n,{type:"separator"},...e.slice(i)]}return p(e)};if(process.argv.includes("--ozone-platform=x11")){const r=8,i=new Map,s=[{x:-2,y:-2,width:1,height:1}],o=(e,t,n)=>{const i=[];for(const s of e){if(!s||![s.x,s.y,s.width,s.height].every(Number.isFinite)||s.width<=0||s.height<=0)continue;const e=Math.max(0,Math.floor(s.x-r)),o=Math.max(0,Math.floor(s.y-r)),a=Math.min(t,Math.ceil(s.x+s.width+r)),c=Math.min(n,Math.ceil(s.y+s.height+r));a>e&&c>o&&i.push({x:e,y:o,width:a-e,height:c-o})}return i},h=(e,t)=>!t||!t.length||!(!e||!e.length)&&t.every(t=>e.some(e=>t.x>=e.x&&t.y>=e.y&&t.x+t.width<=e.x+e.width&&t.y+t.height<=e.y+e.height)),m=(e,t,n)=>e.map(e=>{const r=Math.max(0,e.x-64),i=Math.max(0,e.y-36),s=Math.min(t,e.x+e.width+64),o=Math.min(n,e.y+e.height+36);return{x:r,y:i,width:s-r,height:o-i}}),f=(e,t)=>{const n=JSON.stringify(t);e.key!==n&&(e.origSetShape(t),e.key=n)},a=e=>{const{window:t}=e;if(t.isDestroyed())return;const n=e.enabled?e.rectangles:[];if(!n.length)return e.settleTimer&&(clearTimeout(e.settleTimer),e.settleTimer=null),e.appliedRects=[],e.tightKey="[]",f(e,s),void e.setIgnoreMouseEvents(!1);const r=JSON.stringify(n);if(r===e.tightKey&&e.appliedRects.length>0)return;if(e.tightKey=r,e.settleTimer&&(clearTimeout(e.settleTimer),e.settleTimer=null),!e.appliedRects.length)e.appliedRects=n,f(e,n);else if(!h(e.appliedRects,n)){const r=t.getContentBounds(),i=m(n,r.width,r.height);e.appliedRects=i,f(e,i)}e.settleTimer=setTimeout(()=>{if(e.settleTimer=null,t.isDestroyed()||!e.enabled)return;const n=e.rectangles;JSON.stringify(n)===r&&n.length&&(e.appliedRects=n,f(e,n))},260),e.setIgnoreMouseEvents(!1)},c=e=>{e.isDestroyed()||e.webContents.isDestroyed()||e.webContents.executeJavaScript("(()=>{if(globalThis.__wisprLocalMeetingClickHandler)window.removeEventListener('click',globalThis.__wisprLocalMeetingClickHandler,!0);if(globalThis.__wisprShapeAnimObserver){globalThis.__wisprShapeAnimObserver.disconnect();globalThis.__wisprShapeAnimObserver=null}const e=e=>{const t=e.target instanceof Element?e.target:null,n=t?.closest('[data-testid=flowbar-meeting-wave-pill]');if(!n)return;const r=t.closest('button,[data-testid=status-stop-button],[data-testid=status-cancel-button]');r&&r!==n&&n.contains(r)||(e.preventDefault(),e.stopImmediatePropagation(),window.electron.ipc.send('meetingRecorder:focusMostRecent',{openConference:!1}))};globalThis.__wisprLocalMeetingClickHandler=e,window.addEventListener('click',e,!0),document.dispatchEvent(new Event('status-window-shape-remeasure',{bubbles:!0}))})()").catch(()=>{})},l=e=>{if(e.isDestroyed()||i.has(e.webContents.id)||!["Status","Flow Status Indicator"].includes(e.getTitle()))return;const t={window:e,rectangles:[],appliedRects:[],tightKey:null,settleTimer:null,enabled:!0,key:null,origSetShape:e.setShape.bind(e),setIgnoreMouseEvents:e.setIgnoreMouseEvents.bind(e)},n=()=>{if(!e.isDestroyed()){try{e.setTitle("Flow Status Indicator")}catch{}try{e.setAlwaysOnTop(!1),e.setAlwaysOnTop(!0,"screen-saver")}catch{}try{e.setVisibleOnAllWorkspaces(!0,{visibleOnFullScreen:!0})}catch{}}};i.set(e.webContents.id,t),t.setIgnoreMouseEvents(!1),e.setShape=()=>{},e.setIgnoreMouseEvents=()=>{},e.on("page-title-updated",e=>e.preventDefault()),n(),setTimeout(n,150),setTimeout(n,600),e.on("show",()=>{n(),setTimeout(n,150),a(t)}),e.webContents.on("did-finish-load",()=>{n(),c(e)}),e.webContents.isLoading()||c(e),e.webContents.on("did-start-loading",()=>{t.rectangles=[],t.appliedRects=[],t.tightKey=null,t.key=null,a(t)}),e.on("closed",()=>{t.settleTimer&&clearTimeout(t.settleTimer),i.delete(e.webContents.id)}),a(t)};e.on("browser-window-created",(e,t)=>l(t));for(const e of t.getAllWindows())l(e);d("status:reportAlphaCatchRects",(e,t)=>{const n=i.get(e.sender.id);if(!n||!t||!Array.isArray(t.rects)||!Array.isArray(t.shapeRects)||t.rects.length>512||t.shapeRects.length>512)return;const r=n.window.getContentBounds();t.viewport&&!(Math.abs(t.viewport.width-r.width)>2||Math.abs(t.viewport.height-r.height)>2)&&(n.rectangles=o([...t.rects,...t.shapeRects],r.width,r.height).slice(0,128),a(n))});for(const[e,t]of[["status:barHidden",!1],["status:barVisible",!0]])d(e,e=>{const n=i.get(e.sender.id);n&&(n.enabled=t,a(n))})}}catch{}})();'''
first, nl, rest = src.partition("\n")
if first.startswith("/*!") and first.rstrip().endswith("*/") and nl:
	src = first + "\n" + shim + "\n" + rest
else:
	src = shim + "\n" + src

with io.open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
	f.write(src)
print("Patched: Linux native system audio capture (--capture-system-audio) enabled.")
PY

# --- Verify the result --------------------------------------------------------
patch_verify_marker
patch_expect_shape -qF \
	'["--capture-system-audio"],{windowsHide:!0,stdio:"pipe",env:/*'"$MARKER"'*/process.env}' \
	-- 'system-audio spawn env not in expected form.'

patch_finish "native system audio capture enabled on Linux in $BUNDLE"
