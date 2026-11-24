#!/usr/bin/env bash
#===============================================================================
# linux-meeting-recorder.sh -- make the Meeting Recorder ("Notetaker") window
# behave like a normal workspace window on Linux and bring it to the active
# workspace + top of stack when clicking the floating Status pill; also wire
# Notetaker live microphone switching from the Status Pill context menu.
#
# Usage: linux-meeting-recorder.sh <path-to-.webpack/main/index.js>
#===============================================================================
set -euo pipefail

# shellcheck source=scripts/patches/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
patch_begin "WISPR_LINUX_MEETING_RECORDER" "${1:-}"

python3 - "$BUNDLE" "$MARKER" <<'PY'
import io, re, sys

path, marker = sys.argv[1], sys.argv[2]
with io.open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
	src = f.read()

ID = r'[\w$]+'
anchor = re.compile(
	r'(?P<N>' + ID + r')=\((?P<e>' + ID + r'),(?P<t>' + ID + r')=(?P<E>' + ID + r')\((?P=e)\),(?P<n>' + ID + r')="focused"\)=>\{'
	r'if\(!(?P=e)\.isDestroyed\(\)\)\{'
	r'if\((?P=t)\|\|(?P=e)\.setBounds\((?P<_>' + ID + r')\(\)\),!(?P<c>' + ID + r')\.tD\)'
	r'return (?P=e)\.isMinimized\(\)&&(?P=e)\.restore\(\),'
	r'void\("inactive"===(?P=n)\?(?P=e)\.showInactive\(\):'
	r'\((?P=e)\.isVisible\(\)\|\|(?P=e)\.show\(\),(?P=e)\.focus\(\),"focused"!==(?P=n)\|\|(?P=e)\.isDestroyed\(\)\|\|(?P<T>' + ID + r')\(\)\)\);'
)
ms = list(anchor.finditer(src))
if len(ms) != 1:
	sys.exit(f"ERROR: expected 1 MeetingRecorder focus N anchor, found {len(ms)}.")

m = ms[0]
e, t, E, n, _, c, T, N = m['e'], m['t'], m['E'], m['n'], m['_'], m['c'], m['T'], m['N']
repl = (
	f'{N}=({e},{t}={E}({e}),{n}="focused")=>{{if(!{e}.isDestroyed()){{'
	f'if({t}||{e}.setBounds({_}()),!{c}.tD)'
	f'return {e}.isMinimized()&&{e}.restore(),'
	f'void("inactive"==={n}?{e}.showInactive():'
	f'(("focused"==={n}&&/*{marker}*/"linux"===process.platform&&globalThis.__wisprActivateRecorder?.({e})),'
	f'{e}.isVisible()||{e}.show(),{e}.moveTop?.(),{e}.focus(),"focused"!=={n}||{e}.isDestroyed()||{T}()));'
)
src = src[:m.start()] + repl + src[m.end():]

shim = r'''/*WISPR_LINUX_MEETING_RECORDER_RUNTIME*/;(function(){if("linux"!==process.platform)return;try{const{app:e,ipcMain:t}=require("electron"),{execFile:n}=require("child_process");if(!e||!t)return;e.on("web-contents-created",(e,t)=>{try{const e=t.send.bind(t);t.send=function(n,...r){try{"media:startMeetingMicCapture"===n&&r[0]?.sessionId?(globalThis.__wisprHubWc=t,globalThis.__wisprMeetingSessionId=r[0].sessionId):"media:stopMeetingMicCapture"===n&&r[0]?.sessionId===globalThis.__wisprMeetingSessionId&&(globalThis.__wisprMeetingSessionId=null)}catch{}return e(n,...r)}}catch{}});t.on("wispr-linux:pin-notetaker-mic",(e,t)=>{try{const n=globalThis.__wisprHubWc,r=globalThis.__wisprMeetingSessionId;n&&!n.isDestroyed()&&r&&n.send("media:pinMeetingMicDevice",{sessionId:r,deviceId:t&&"default"!==t?t:null,generation:Date.now()})}catch{}});globalThis.__wisprActivateRecorder=e=>{if(!e||e.isDestroyed())return;try{e.setSkipTaskbar(!1),e.setVisibleOnAllWorkspaces(!1)}catch{}try{n("gdbus",["call","--session","--dest","org.wispr.flow.WindowBridge","--object-path","/org/wispr/flow/WindowBridge","--method","org.wispr.flow.WindowBridge.ActivateWindow",e.getTitle()||"Meeting Recorder"],{timeout:2e3},()=>{})}catch{}try{if(process.env.DISPLAY&&(!process.env.WAYLAND_DISPLAY||process.argv.includes("--ozone-platform=x11"))){const t=e.getNativeWindowHandle().readUInt32LE(0);t&&n("python3",["-c","import ctypes as C,sys;x=C.CDLL('libX11.so.6');x.XOpenDisplay.restype=C.c_void_p;x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong;x.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int];x.XInternAtom.restype=C.c_ulong;x.XGetWindowProperty.argtypes=[C.c_void_p,C.c_ulong,C.c_ulong,C.c_long,C.c_long,C.c_int,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_int),C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.c_void_p)];x.XFree.argtypes=[C.c_void_p];x.XSendEvent.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_long,C.c_void_p];x.XSync.argtypes=[C.c_void_p,C.c_int];x.XCloseDisplay.argtypes=[C.c_void_p]\nclass E(C.Structure):_fields_=[('type',C.c_int),('serial',C.c_ulong),('send_event',C.c_int),('display',C.c_void_p),('window',C.c_ulong),('message_type',C.c_ulong),('format',C.c_int),('data',C.c_long*5)]\nd=x.XOpenDisplay(None)\nif d:\n try:\n  r=x.XDefaultRootWindow(d);w=int(sys.argv[1])\n  def A(s):return x.XInternAtom(d,s.encode(),False)\n  t,f,c,af,p=C.c_ulong(),C.c_int(),C.c_ulong(),C.c_ulong(),C.c_void_p()\n  dt=0\n  if 0==x.XGetWindowProperty(d,r,A('_NET_CURRENT_DESKTOP'),0,1,False,0,C.byref(t),C.byref(f),C.byref(c),C.byref(af),C.byref(p)) and p.value:\n   dt=C.cast(p,C.POINTER(C.c_ulong))[0];x.XFree(p)\n  def S(n,v):\n   ev=E(type=33,send_event=1,display=d,window=w,message_type=A(n),format=32);ev.data=(C.c_long*5)(*v)\n   x.XSendEvent(d,r,False,(1<<20)|(1<<19),C.byref(ev))\n  S('_NET_WM_DESKTOP',[dt,2,0,0,0]);S('_NET_ACTIVE_WINDOW',[2,0,0,0,0]);x.XSync(d,False)\n finally:x.XCloseDisplay(d)",String(t)],{timeout:2e3},()=>{})}}catch{}}}catch{}})();'''
first, nl, rest = src.partition("\n")
if first.startswith("/*!") and first.rstrip().endswith("*/") and nl:
	src = first + "\n" + shim + "\n" + rest
else:
	src = shim + "\n" + src

with io.open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
	f.write(src)
print("Patched: Meeting Recorder Linux workspace activation & live mic pin enabled.")
PY

patch_verify_marker
patch_expect_shape -qF \
	'/*'"$MARKER"'*/"linux"===process.platform&&globalThis.__wisprActivateRecorder' \
	-- 'Meeting Recorder focus activation branch not in expected form.'

patch_finish "Meeting Recorder focus and mic pin enabled in $BUNDLE"
