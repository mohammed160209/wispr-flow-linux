#!/usr/bin/env bash
#===============================================================================
# linux-context-menu-notetaker-mic.sh -- keep the normal Microphone input
# device selection list in the Status Pill right-click submenu even when
# Notetaker is active, with "Auto-detect" ("default") selected by default.
#
# Usage: linux-context-menu-notetaker-mic.sh <path-to-.webpack/renderer/contextMenu/index.js>
#===============================================================================
set -euo pipefail

# shellcheck source=scripts/patches/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
patch_begin "WISPR_LINUX_CONTEXT_MENU_NOTETAKER_MIC" "${1:-}"

python3 - "$BUNDLE" "$MARKER" <<'PY'
import io, re, sys

path, marker = sys.argv[1], sys.argv[2]
with io.open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
	src = f.read()

ID = r'[\w$]+'

# 1. Add per-session Notetaker selected mic state defaulting to "default" (Auto-detect).
state_anchor = re.compile(
	r'(?P<r>' + ID + r')=\(0,(?P<q>' + ID + r')\.(?P<CU>' + ID + r')\)\((?P<ae>' + ID + r')=>(?P=ae)\.audioDevices\?\?(?P<Gs>' + ID + r')\),'
	r'\[(?P<s>' + ID + r'),(?P<under>' + ID + r')\]=\(0,(?P<b>' + ID + r')\.useState\)\(!1\),'
	r'(?P<l>' + ID + r')=\(0,(?P=q)\.(?P=CU)\)\((?P<ae2>' + ID + r')=>\(0,(?P<B>' + ID + r')\.(?P<Zb>' + ID + r')\)\(\(0,(?P<U>' + ID + r')\.(?P<vP>' + ID + r')\)\((?P=ae2)\)\)\),'
)
ms1 = list(state_anchor.finditer(src))
if len(ms1) != 1:
	sys.exit(f"ERROR: expected 1 contextMenu state anchor, found {len(ms1)}.")

m1 = ms1[0]
b = m1['b']
state_repl = m1.group(0) + f'[__wisprNtMic,__wisprSetNtMic]=(0,{b}.useState)("default"),'
src = src[:m1.start()] + state_repl + src[m1.end():]

# 2. Replace the Notetaker lockout branch in Ee(t, n) with the full input device list,
# defaulting selection to __wisprNtMic ("default" = Auto-detect) while Notetaker is active.
ee_anchor = re.compile(
	r'const (?P<Ee>' + ID + r')=\(0,' + b + r'\.useCallback\)\(\((?P<t>' + ID + r'),(?P<n>' + ID + r')\)=>\{'
	r'const (?P<i>' + ID + r')=(?P<e>' + ID + r')\("settings_languages_auto_detect_toggle"\),'
	r'(?P<r>' + ID + r')=(?P=e)\("settings_microphone_built_in_recommended"\),'
	r'(?P<l>' + ID + r')=(?P=e)\("settings_microphone_unknown"\);'
	r'let (?P<d>' + ID + r'),(?P<c>' + ID + r'),(?P<u>' + ID + r');'
	r'if\((?P=n)\)\{.{100,900}?\}else\{'
	r'(?P=c)=(?P=e)\("hub_status_menu_microphone",\{ns:"hub"\}\);'
	r'const (?P=n)=(?P<el>' + ID + r')=>\(\{type:(?P<te>' + ID + r')\.v\.Button,label:(?P<Mn>' + ID + r')\((?P<Rn>' + ID + r')\((?P=el)\.name,(?P=i)\),(?P=r)\),disabled:null!=(?P=el)\.unavailableReason,'
	r'onClick:\(\)=>\{(?P<v>' + ID + r')\.m\.info\(`Selected microphone in status bubble: \$\{(?P=el)\.deviceId\}, name: \$\{(?P=el)\.name\}`\),'
	r'(?P<qn>' + ID + r')\(\{deviceId:(?P=el)\.deviceId,name:(?P=el)\.name,isVirtual:(?P=el)\.isVirtual\},"flow_bar",\{rankedAudioDevices:(?P<o>' + ID + r')\.user\.rankedAudioDevices,connectedDeviceIds:new Set\((?P=t)\.map\((?P<m1>' + ID + r')=>(?P=m1)\.deviceId\)\),updateUserPrefs:(?P<a>' + ID + r'),fromDevice:(?P=t)\.find\((?P<m2>' + ID + r')=>(?P=m2)\.selected\)\}\)\},selected:(?P=el)\.selected\}\),'
	r'(?P<p>' + ID + r')=\((?P<pa>' + ID + r'),(?P<pb>' + ID + r')\)=>(?P=pa)\.selected\?1:(?P=pb)\.selected\?-1:0,'
	r'(?P<m>' + ID + r')=(?P=t)\.filter\((?P<mf>' + ID + r')=>!(?P=mf)\.isVirtual\),'
	r'(?P<h>' + ID + r')=(?P=t)\.filter\((?P<hf>' + ID + r')=>(?P=hf)\.isVirtual\),'
	r'(?P<g>' + ID + r')=(?P=t)\.some\((?P<gf>' + ID + r')=>(?P=gf)\.selected&&(?P=gf)\.isVirtual\),'
	r'(?P<bb>' + ID + r')=' + m1['s'] + r'\|\|(?P=g),'
	r'(?P<f>' + ID + r')=(?P=m)\.map\((?P=n)\);'
	r'if\((?P=f)\.sort\((?P=p)\),(?P=h)\.length>0\)\{if\((?P=bb)\)\{const (?P=e)=(?P=h)\.map\((?P=n)\);(?P=e)\.sort\((?P=p)\),(?P=f)\.push\(\.\.\.(?P=e)\)\}'
	r'(?P=f)\.push\(\{type:(?P=te)\.v\.Button,label:(?P=bb)\?(?P=e)\("hub_status_menu_microphone_hide_virtual",\{ns:"hub"\}\):(?P=e)\("hub_status_menu_microphone_show_virtual",\{ns:"hub",count:(?P=h)\.length\}\),keepOpen:!0,'
	r'onClick:\(\)=>\{if\((?P=bb)\)\{if\((?P=g)\)\{const (?P=e)=(?P=t)\.find\((?P<tf>' + ID + r')=>(?P=tf)\.deviceId===(?P<Pn>' + ID + r')\);'
	r'(?P=qn)\(\{deviceId:(?P=Pn),name:(?P=e)\?\.name\?\?(?P=i)\},"flow_bar",\{rankedAudioDevices:(?P=o)\.user\.rankedAudioDevices,connectedDeviceIds:new Set\((?P=t)\.map\((?P<tf2>' + ID + r')=>(?P=tf2)\.deviceId\)\),updateUserPrefs:(?P=a),fromDevice:(?P=t)\.find\((?P<tf3>' + ID + r')=>(?P=tf3)\.selected\)\}\)\}' + m1['under'] + r'\(!1\)\}else ' + m1['under'] + r'\(!0\)\}\}\)\}'
	r'(?P=d)=(?P=f),(?P=u)=\{type:(?P=te)\.v\.Text,text:\(0,(?P<C>' + ID + r')\.jsxs\)\("div",\{children:\[\(0,(?P=C)\.jsx\)\("span",\{children:`\$\{(?P=e)\("settings_context_menu_mic_in_use_prefix"\)\} `\}\),\(0,(?P=C)\.jsx\)\("span",\{children:(?P=Mn)\((?P=Rn)\((?P<Fn>' + ID + r')\((?P=t),(?P=l)\),(?P=i)\),(?P=r)\)\}\)\]\}\)\}\}'
	r'(?P<w>' + ID + r')\((?P=e)=>(?P=e)\.map\((?P=e)=>(?P=e)\.type===(?P=te)\.v\.Submenu&&(?P=e)\.id===(?P<W>' + ID + r')\.bE\.MICROPHONE\?\{\.\.\.(?P=e),label:(?P=c),items:(?P=d),itemBelowSelected:(?P=u)\}:(?P=e)\)\)\},'
	r'\[(?P=e),(?P=a),(?P=o)\.user\.rankedAudioDevices,' + m1['s'] + r'\]\);'
	r'return\(0,' + b + r'\.useEffect\)\(\(\)=>\{(?P=Ee)\(' + m1['r'] + r',' + m1['l'] + r'\)\},\[' + m1['r'] + r',' + m1['l'] + r',(?P=Ee)\]\),'
)
ms2 = list(ee_anchor.finditer(src))
if len(ms2) != 1:
	sys.exit(f"ERROR: expected 1 contextMenu Ee mic submenu anchor, found {len(ms2)}.")

m2 = ms2[0]
Ee = m2['Ee']
t, n, i, e, r, l = m2['t'], m2['n'], m2['i'], m2['e'], m2['r'], m2['l']
d, c, u = m2['d'], m2['c'], m2['u']
te, Mn, Rn, Fn, qn, Pn = m2['te'], m2['Mn'], m2['Rn'], m2['Fn'], m2['qn'], m2['Pn']
v, o, a, p, m, h, g, bb, f = m2['v'], m2['o'], m2['a'], m2['p'], m2['m'], m2['h'], m2['g'], m2['bb'], m2['f']
C, w, W = m2['C'], m2['w'], m2['W']
under, s_var = m1['under'], m1['s']
r_st, l_st = m1['r'], m1['l']

# Note: rename shadowed param `e` inside item helper to avoid capturing outer `t` cleanly.
repl2 = (
	f'const {Ee}=(0,{b}.useCallback)(({t},{n})=>{{'
	f'const {i}={e}("settings_languages_auto_detect_toggle"),'
	f'{r}={e}("settings_microphone_built_in_recommended"),'
	f'{l}={e}("settings_microphone_unknown"),'
	f'__wisprIsNt=/*{marker}*/!!{n},'
	f'__wisprDevs=__wisprIsNt?({t}||[]).map(x=>({{...x,selected:x.deviceId===__wisprNtMic}})):{t};'
	f'let {d},{c},{u};'
	f'{c}={e}(__wisprIsNt?"hub_status_menu_microphone_notetaker":"hub_status_menu_microphone",{{ns:"hub"}});'
	f'const __item=x=>({{type:{te}.v.Button,label:{Mn}({Rn}(x.name,{i}),{r}),disabled:null!=x.unavailableReason,'
	f'onClick:()=>{{if(__wisprIsNt){{__wisprSetNtMic(x.deviceId);try{{window.electron?.ipc?.send?.("wispr-linux:pin-notetaker-mic",x.deviceId)}}catch{{}}}}'
	f'else{{{v}.m.info(`Selected microphone in status bubble: ${{x.deviceId}}, name: ${{x.name}}`),'
	f'{qn}({{deviceId:x.deviceId,name:x.name,isVirtual:x.isVirtual}},"flow_bar",{{rankedAudioDevices:{o}.user.rankedAudioDevices,connectedDeviceIds:new Set(__wisprDevs.map(y=>y.deviceId)),updateUserPrefs:{a},fromDevice:__wisprDevs.find(y=>y.selected)}})}}}},selected:x.selected}}),'
	f'{p}=(x,y)=>x.selected?1:y.selected?-1:0,'
	f'{m}=__wisprDevs.filter(x=>!x.isVirtual),'
	f'{h}=__wisprDevs.filter(x=>x.isVirtual),'
	f'{g}=__wisprDevs.some(x=>x.selected&&x.isVirtual),'
	f'{bb}={s_var}||{g},'
	f'{f}={m}.map(__item);'
	f'if({f}.sort({p}),{h}.length>0){{if({bb}){{const x={h}.map(__item);x.sort({p}),{f}.push(...x)}}'
	f'{f}.push({{type:{te}.v.Button,label:{bb}?{e}("hub_status_menu_microphone_hide_virtual",{{ns:"hub"}}):{e}("hub_status_menu_microphone_show_virtual",{{ns:"hub",count:{h}.length}}),keepOpen:!0,'
	f'onClick:()=>{{if({bb}){{if({g}){{if(__wisprIsNt){{__wisprSetNtMic({Pn});try{{window.electron?.ipc?.send?.("wispr-linux:pin-notetaker-mic",{Pn})}}catch{{}}}}else{{const x=__wisprDevs.find(y=>y.deviceId==={Pn});'
	f'{qn}({{deviceId:{Pn},name:x?.name??{i}}},"flow_bar",{{rankedAudioDevices:{o}.user.rankedAudioDevices,connectedDeviceIds:new Set(__wisprDevs.map(y=>y.deviceId)),updateUserPrefs:{a},fromDevice:__wisprDevs.find(y=>y.selected)}})}}}}{under}(!1)}}else {under}(!0)}}}})}}'
	f'{d}={f},{u}={{type:{te}.v.Text,text:(0,{C}.jsxs)("div",{{children:[(0,{C}.jsx)("span",{{children:`${{{e}("settings_context_menu_mic_in_use_prefix")}} `}}),(0,{C}.jsx)("span",{{children:{Mn}({Rn}({Fn}(__wisprDevs,{l}),{i}),{r})}})]}})}};'
	f'{w}(x=>x.map(x=>x.type==={te}.v.Submenu&&x.id==={W}.bE.MICROPHONE?{{...x,label:{c},items:{d},itemBelowSelected:{u}}}:x))}},'
	f'[{e},{a},{o}.user.rankedAudioDevices,{s_var},__wisprNtMic]);'
	f'return(0,{b}.useEffect)(()=>{{{l_st}&&__wisprSetNtMic("default")}},[{l_st}]),'
	f'(0,{b}.useEffect)(()=>{{{Ee}({r_st},{l_st})}},[{r_st},{l_st},{Ee}]),'
)
src = src[:m2.start()] + repl2 + src[m2.end():]

with io.open(path, "w", encoding="utf-8", errors="surrogateescape") as f_out:
	f_out.write(src)
print("Patched: Status pill Microphone submenu keeps full device list during Notetaker with Auto default.")
PY

patch_verify_marker
patch_expect_shape -qF \
	'__wisprIsNt=/*'"$MARKER"'*/!!' \
	-- 'contextMenu Notetaker mic selector branch not in expected form.'

patch_finish "contextMenu Notetaker microphone menu enabled in $BUNDLE"
