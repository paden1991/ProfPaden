from pathlib import Path
import json,sys
from lupa.lua51 import LuaRuntime
R=Path(__file__).resolve().parents[1];D=R/'docs/sleeping-bag-2026-11-24';D.mkdir(exist_ok=True)
SETUP='''
Clock=100;Combat=false;Auras={};Reads=0;function GetTime()return Clock end;function InCombatLockdown()return Combat end
local M={};Frames={}
for _,k in ipairs({'SetFrameStrata','SetClampedToScreen','SetMovable','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetTexture','SetTexCoord','SetVertexColor','SetFont','SetTextColor','SetShadowColor','SetShadowOffset','SetJustifyH','SetColorTexture','SetAllPoints','SetStatusBarTexture','SetMinMaxValues','SetStatusBarColor','RegisterForDrag','RegisterEvent','StartMoving','StopMovingOrSizing'}) do M[k]=function()end end
function M:SetScript(k,f)self.scripts[k]=f end;function M:SetSize(w,h)self.width=w;self.height=h end;function M:SetWidth(w)self.width=w end
function M:SetFrameStrata(s)self.strata=s end
function M:SetPoint(...)self.point={...}end;function M:ClearAllPoints()self.point=nil end;function M:GetCenter()return self.x or 640,self.y or 360 end
function M:SetText(t)self.text=t end;function M:SetValue(v)self.value=v end;function M:SetAlpha(v)self.alpha=v end
function M:SetChecked(v)self.checked=v end;function M:GetChecked()return self.checked end
function M:Show()self.shown=true end;function M:Hide()self.shown=false end;function M:IsShown()return self.shown end;function M:EnableMouse(v)self.mouse=v end
function CreateFrame(kind,name,parent,template)local f=setmetatable({scripts={},shown=true,parent=parent,template=template}, {__index=M});Frames[#Frames+1]=f;if name then _G[name]=f end;return f end
function M:CreateTexture()return CreateFrame('Texture',nil,self)end;function M:CreateFontString()return CreateFrame('Font',nil,self)end
UIParent=CreateFrame('Frame');SlashCmdList={};P={char={}}
function P:Print(s)self.message=s end
C_UnitAuras={GetPlayerAuraBySpellID=function(id)assert(not Combat,'Read in combat');Reads=Reads+1;return Auras[id] end}
Secret=setmetatable({},{__index=function()error('Secret table indexed')end})
function canaccessvalue(v)return v~=Secret end;function issecretvalue(v)return v==Secret end;function canaccesstable(v)return v~=Secret end
function aura(n,e)Auras[1331671]={};Auras[429959]=n>0 and {applications=n,expirationTime=e or 7300} or nil end
'''
results=[]
def test(name,code):
 try:
  l=LuaRuntime();l.execute(SETUP);l.execute((R/'ProfPaden/SleepTimer.lua').read_text(encoding='utf8'),'ProfPaden',l.globals().P);l.execute(code);results.append({'name':name,'passed':True})
 except Exception as e:results.append({'name':name,'passed':False,'error':str(e)})
test('Starts on bag aura; exactly 320 by 64 and click-through normally','''
aura(0);P:UpdateSleepTimer();local f=P.sleepTimerFrame;assert(f.width==320 and f.height==64 and f.shown and not f.mouse)
assert(f.clock.text=='~1:00' and f.footer.text=='Full stacks in ~3:00')
Clock=118;P:UpdateSleepTimer();assert(f.clock.text=='~0:42' and P.sleepTimerState.deadline==160)
''')
test('Three actual stack events reset the minute and completion fades once','''
aura(0);P:UpdateSleepTimer();Clock=160;aura(1);P:UpdateSleepTimer();Clock=178;P:UpdateSleepTimer()
assert(P.sleepTimerFrame.footer.text=='Full stacks in ~1:42')
Clock=220;aura(2);P:UpdateSleepTimer();assert(P.sleepTimerState.deadline==280)
Clock=280;aura(3);P:UpdateSleepTimer();assert(P.sleepTimerState.phase=='complete' and P.sleepTimerFrame.label.text=='3 stacks ready')
Clock=282;P:UpdateSleepTimer();assert(P.sleepTimerState.hideAt==284)
Clock=284;P:RenderSleepTimer();assert(not P.sleepTimerFrame.shown)
Clock=300;P:UpdateSleepTimer();assert(not P.sleepTimerFrame.shown)
''')
test('Countdown never awards fabricated stacks when the server has not granted them','''
aura(0);P:UpdateSleepTimer();Clock=500;P:UpdateSleepTimer();assert(P.sleepTimerState.stacks==0)
assert(P.sleepTimerFrame.label.text=='Waiting for stack' and P.sleepTimerFrame.bar.value==0)
''')
test('Leaving stops progression; reentry resets the partial minute, keeping real stacks','''
aura(1);P:UpdateSleepTimer();Clock=120;Auras[1331671]=nil;P:UpdateSleepTimer();assert(P.sleepTimerState.phase=='interrupted' and not P.sleepTimerState.deadline)
Clock=124;P:RenderSleepTimer();assert(not P.sleepTimerFrame.shown)
Clock=130;aura(1);P:UpdateSleepTimer();assert(P.sleepTimerState.deadline==190 and P.sleepTimerState.stacks==1)
''')
test('Three existing stacks show refresh countdown until the real expiration increases','''
aura(3,7300);P:UpdateSleepTimer();assert(P.sleepTimerState.phase=='refresh')
Clock=160;P:UpdateSleepTimer();assert(P.sleepTimerFrame.label.text=='Waiting for stack')
aura(3,7360);P:UpdateSleepTimer();assert(P.sleepTimerState.phase=='complete')
''')
test('Existing buff outside the bag does not show a timer or completion popup','''
Auras[429959]={applications=3,expirationTime=7300};P:UpdateSleepTimer();assert(not P.sleepTimerFrame)
''')
test('Combat hides and clears the countdown without reading restricted auras','''
aura(1);P:UpdateSleepTimer();local n=Reads;Combat=true;P:UpdateSleepTimer();assert(Reads==n and not P.sleepTimerFrame.shown and not P.sleepTimerState)
Combat=false;Clock=200;P:UpdateSleepTimer();assert(P.sleepTimerState.deadline==260)
''')
test('Unavailable, secret containers and secret counts are never used or formatted','''
aura(1);Auras[1331671]=Secret;assert(P:ReadSleepAuras()==nil)
aura(1);Auras[429959].applications=Secret;assert(P:ReadSleepAuras()==nil)
aura(1);canaccessvalue=function()return true end;issecretvalue=function()return false end;Auras[429959]=Secret;assert(P:ReadSleepAuras()==nil)
C_UnitAuras=nil;assert(P:ReadSleepAuras()==nil)
''')
test('Malformed stack counts are rejected; unrelated legacy talent does not qualify','''
for _,n in ipairs({-1,1.5,math.huge,'1'}) do aura(1);Auras[429959].applications=n;assert(P:ReadSleepAuras()==nil) end
Auras={[1225478]={applications=3}};P:UpdateSleepTimer();assert(not P.sleepTimerFrame)
''')
test('Preview lasts 15 seconds, is draggable, and does not change real state','''
P:UpdateSleepTimer();local old=P.sleepTimerState;P:PreviewSleepTimer();assert(P.sleepTimerFrame.mouse and P.sleepTimerState==old)
assert(P.sleepTimerFrame.strata=='TOOLTIP')
Clock=115;P.sleepTimerFrame.scripts.OnUpdate(P.sleepTimerFrame,.1);assert(not P.sleepTimerPreview and not P.sleepTimerFrame.shown)
''')
test('Actual resting takes precedence over preview','''
P:PreviewSleepTimer();aura(2);P:UpdateSleepTimer();assert(not P.sleepTimerPreview and P.sleepTimerState.stacks==2 and not P.sleepTimerFrame.mouse)
assert(P.sleepTimerFrame.strata=='MEDIUM')
''')
test('Position is persisted, invalid position is handled, reset only clears this position','''
P.char.sleepTimerPosition={x='bad',y={}};P:PreviewSleepTimer();local f=P.sleepTimerFrame;assert(f.point[4]==0 and f.point[5]==-180)
f.x=700;f.y=300;f.scripts.OnDragStop();assert(P.char.sleepTimerPosition.x==60 and P.char.sleepTimerPosition.y==-60)
P.char.unrelated=123;SlashCmdList.PROFPADENSLEEP('reset');assert(not P.char.sleepTimerPosition and P.char.unrelated==123)
''')
test('Saved false preference is respected; on and off apply immediately','''
P.char.sleepTimerEnabled=false;aura(0);P:UpdateSleepTimer();assert(not P.sleepTimerFrame)
SlashCmdList.PROFPADENSLEEP('on');assert(P.sleepTimerFrame.shown)
SlashCmdList.PROFPADENSLEEP('off');assert(not P.sleepTimerFrame.shown and P.char.sleepTimerEnabled==false)
''')
test('World entry restarts an estimated minute and ignores target/secret unit aura events','''
aura(1);P:UpdateSleepTimer();Clock=120;P.sleepTimerEvents.scripts.OnEvent(nil,'UNIT_AURA','target');assert(P.sleepTimerState.deadline==160)
P.sleepTimerEvents.scripts.OnEvent(nil,'UNIT_AURA',Secret);assert(P.sleepTimerState.deadline==160)
P.sleepTimerEvents.scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');assert(P.sleepTimerState.deadline==180)
''')
test('Settings support late load and register a single category','''
P:RegisterSleepTimerOptions();assert(not P.sleepTimerOptions)
local count=0;Settings={RegisterCanvasLayoutCategory=function(panel,name)return {name=name} end,RegisterAddOnCategory=function()count=count+1 end}
P:RegisterSleepTimerOptions();P:RegisterSleepTimerOptions();assert(count==1)
P.char.sleepTimerEnabled=false;P.sleepTimerOptions.scripts.OnShow()
local checkbox;for _,f in ipairs(Frames)do if f.template=='UICheckButtonTemplate' then checkbox=f end end
assert(checkbox.checked==false);checkbox.checked=true;checkbox.scripts.OnClick(checkbox);assert(P.char.sleepTimerEnabled)
''')
report={'tests':len(results),'passed':sum(x['passed'] for x in results),'results':results,'scope':'Production Lua 5.1; simulated aura state, events, clock and UI; no live WoW claim'}
(D/'tests.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
