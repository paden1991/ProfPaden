local addon,P=...
-- Forever: Resting was added for sleeping-bag proximity on 2026-11-17.
-- Never use generic rested-XP, sitting, or the item's placement cooldown.
P.sleepRestAura=1331671
P.sleepBuffAura=429959
local L={title="Sleeping Bag",complete="Well-Rested",next="Next stack",refresh="Refresh buff",
    full="Full stacks in ~%s",refreshing="Refreshing existing stacks",ready="3 stacks ready",
    done="Ready to adventure",away="Not resting",returnBag="Return to your sleeping bag",
    waiting="Waiting for stack",confirm="Waiting for buff confirmation",preview="Preview - drag to move",
    settings="ProfPaden - Sleeping Bag",enabled="Show sleeping-bag timer",previewButton="Preview / move",
    reset="Reset position",help="A compact countdown while resting in a sleeping bag. Stack markers use the actual buff; times between stacks are estimates. Preview unlocks dragging for 15 seconds.",
    commands="/ppsleep preview, on, off, reset. Options: Settings > AddOns > ProfPaden - Sleeping Bag.",
    combat="Leave combat before previewing or moving the timer."}
P.SleepTimerL=L -- Complete English fallback; spell matching uses IDs in every locale.
local function seconds(n)
    n=math.max(0,math.ceil(n));return string.format("%d:%02d",math.floor(n/60),n%60)
end
local function plain(v)
    if canaccessvalue and not canaccessvalue(v) then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end
local function number(v)
    return plain(v) and type(v)=="number" and v==v and v>=0 and v<math.huge
end
function P:ReadSleepAuras()
    if InCombatLockdown() then return end
    local api=C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not api then return end
    local function read(id)
        -- pcall contains API unavailability; it does not make secret data readable.
        local ok,a=pcall(api,id)
        if not ok or not plain(a) then return nil,false end
        if a==nil then return nil,true end
        if canaccesstable and not canaccesstable(a) then return nil,false end
        if type(a)~="table" then return nil,false end
        return a,true
    end
    local rest,restOK=read(self.sleepRestAura);local buff,buffOK=read(self.sleepBuffAura)
    if not restOK or not buffOK then return end
    local stacks,expires=0,nil
    if buff then
        local count=buff.applications
        if not number(count) or count~=math.floor(count) then return end
        stacks=math.min(3,count)
        local expiry=buff.expirationTime
        if number(expiry) then expires=expiry end
    end
    return rest~=nil,stacks,expires
end
-- Pure state transition, also exercised by the deterministic test harness.
function P:SleepTimerStep(s,now,resting,stacks,expires)
    local wasResting,oldStacks=s.resting,s.stacks or 0
    local active=s.phase=="countdown" or s.phase=="refresh"
    local refreshed=s.phase=="refresh" and expires and s.expires and expires>s.expires+1
    if active and stacks==3 and (oldStacks<3 or refreshed) then
        s.phase="complete";s.hideAt=now+4;s.deadline=nil
    elseif resting then
        if not wasResting or stacks~=oldStacks then
            s.phase=stacks>=3 and "refresh" or "countdown";s.deadline=now+60;s.hideAt=nil
        end
    elseif wasResting and active then
        s.phase="interrupted";s.deadline=nil;s.hideAt=now+4
    elseif s.phase~="complete" and s.phase~="interrupted" then s.phase="idle" end
    s.resting=resting;s.stacks=stacks;s.expires=expires
    return s
end
function P:SleepTimerView(s,now)
    if not s or s.phase=="idle" then return end
    if s.hideAt and now>=s.hideAt then return end
    local v={stacks=s.stacks or 0,alpha=s.hideAt and math.min(1,s.hideAt-now) or 1,title=L.title}
    if s.phase=="complete" then v.title=L.complete;v.label=L.ready;v.footer=L.done;v.value=1;v.green=true;v.time=""
    elseif s.phase=="interrupted" then v.label=L.away;v.footer=L.returnBag;v.value=0;v.time="";v.muted=true
    else
        local left=math.max(0,(s.deadline or now)-now)
        v.value=left/60;v.time="~"..seconds(left)
        v.label=left<=0 and L.waiting or s.phase=="refresh" and L.refresh or L.next
        v.footer=left<=0 and L.confirm or s.phase=="refresh" and L.refreshing or string.format(L.full,seconds(left+math.max(0,2-v.stacks)*60))
        if s.preview then v.footer=L.preview end
    end
    return v
end
function P:PlaceSleepTimer()
    local f=self.sleepTimerFrame;if not f then return end
    local pos=self.char and self.char.sleepTimerPosition
    local x=type(pos)=="table" and pos.x;local y=type(pos)=="table" and pos.y
    if type(x)~="number" or type(y)~="number" or x~=x or y~=y or math.abs(x)>=math.huge or math.abs(y)>=math.huge then x,y=0,-180 end
    f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",x,y)
end
function P:CreateSleepTimer()
    if self.sleepTimerFrame then return self.sleepTimerFrame end
    local f=CreateFrame("Frame","ProfPadenSleepTimer",UIParent,"BackdropTemplate")
    self.sleepTimerFrame=f;f:SetSize(320,64);f:SetFrameStrata("MEDIUM");f:SetClampedToScreen(true);f:SetMovable(true)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
    f:SetBackdropColor(.055,.047,.035,.96);f:SetBackdropBorderColor(.65,.48,.23,1)
    -- Fixed-size artisan corners retain the approved brass detail at HUD scale.
    local art="Interface\\AddOns\\ProfPaden\\Assets\\Theme\\ArtisanFrame.tga"
    for _,c in ipairs({{"TOPLEFT",0,.06,0,.112},{"TOPRIGHT",.94,1,0,.112},{"BOTTOMLEFT",0,.06,.936,1},{"BOTTOMRIGHT",.94,1,.936,1}}) do
        local t=f:CreateTexture(nil,"BORDER");t:SetTexture(art);t:SetTexCoord(c[2],c[3],c[4],c[5]);t:SetSize(15,16);t:SetPoint(c[1],0,0)
    end
    local icon=f:CreateTexture(nil,"ARTWORK");icon:SetSize(34,34);icon:SetPoint("LEFT",8,0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_BigBagofEnchantments");icon:SetTexCoord(.07,.93,.07,.93)
    local function text(parent,size,serif)
        local t=parent:CreateFontString(nil,"OVERLAY");t:SetFont(serif and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF",size,"")
        t:SetTextColor(.96,.91,.79);t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1);return t
    end
    f.title=text(f,13,true);f.title:SetPoint("TOPLEFT",49,-7);f.title:SetWidth(181);f.title:SetJustifyH("LEFT")
    f.pips={}
    for i=1,3 do
        local pip=CreateFrame("Frame",nil,f);pip:SetSize(19,19);pip:SetPoint("TOPRIGHT",-9-(3-i)*23,-5)
        local ring=pip:CreateTexture(nil,"ARTWORK");ring:SetAllPoints();ring:SetTexture("Interface\\Buttons\\UI-RadioButton");ring:SetTexCoord(0,.25,0,1)
        pip.ring=ring;pip.number=text(pip,11);pip.number:SetPoint("CENTER",0,0);pip.number:SetText(i);f.pips[i]=pip
    end
    f.bar=CreateFrame("StatusBar",nil,f);f.bar:SetSize(260,17);f.bar:SetPoint("TOPLEFT",49,-26)
    f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");f.bar:SetMinMaxValues(0,1)
    local bg=f.bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.13,.11,.075,1)
    f.label=text(f.bar,11);f.label:SetPoint("LEFT",5,0);f.label:SetWidth(184);f.label:SetJustifyH("LEFT")
    f.clock=text(f.bar,12);f.clock:SetPoint("RIGHT",-4,0)
    f.footer=text(f,10);f.footer:SetPoint("TOPLEFT",49,-47);f.footer:SetWidth(260);f.footer:SetJustifyH("CENTER")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function()if P.sleepTimerPreview and not InCombatLockdown() then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing();local x,y=f:GetCenter();local px,py=UIParent:GetCenter()
        if x and px and P.char then P.char.sleepTimerPosition={x=x-px,y=y-py} end
    end)
    f:SetScript("OnUpdate",function(_,elapsed)
        f.poll=(f.poll or 0)+elapsed;f.elapsed=(f.elapsed or 0)+elapsed;if f.elapsed<.05 then return end;f.elapsed=0
        local now=GetTime()
        if P.sleepTimerPreview then
            if now>=P.sleepTimerPreview.hideAt or InCombatLockdown() then P.sleepTimerPreview=nil;P:UpdateSleepTimer() else P:RenderSleepTimer(now) end
        else
            if f.poll>=.5 then f.poll=0;P:UpdateSleepTimer() else P:RenderSleepTimer(now) end
        end
    end)
    f:EnableMouse(false);self:PlaceSleepTimer();f:Hide();return f
end
function P:RenderSleepTimer(now)
    local s=self.sleepTimerPreview or self.sleepTimerState
    local v=self:SleepTimerView(s,now or GetTime());local f=self.sleepTimerFrame
    if not v then if f then f:Hide() end;return end
    f=f or self:CreateSleepTimer();f:EnableMouse(self.sleepTimerPreview~=nil);f:SetAlpha(v.alpha)
    -- The move preview must remain usable above the native Settings window.
    f:SetFrameStrata(self.sleepTimerPreview and "TOOLTIP" or "MEDIUM")
    f.title:SetText(v.title);f.label:SetText(v.label);f.clock:SetText(v.time);f.footer:SetText(v.footer)
    f.bar:SetStatusBarColor(v.green and .3 or .72,v.green and .61 or .47,v.green and .24 or .13)
    f.bar:SetValue(v.value)
    for i,pip in ipairs(f.pips) do
        local earned=i<=v.stacks;pip.ring:SetTexCoord(earned and .25 or 0,earned and .5 or .25,0,1)
        pip.ring:SetVertexColor(v.green and .55 or 1,v.green and 1 or .78,v.green and .5 or .37)
        pip.number:SetTextColor(earned and 1 or .65,earned and .94 or .61,earned and .7 or .53)
    end
    f:Show()
end
function P:UpdateSleepTimer()
    if not self.char then return end
    if InCombatLockdown() or self.char.sleepTimerEnabled==false then
        self.sleepTimerPreview=nil;self.sleepTimerState=nil;self:RenderSleepTimer();return
    end
    local resting,stacks,expires=self:ReadSleepAuras()
    if resting==nil then self.sleepTimerState=nil;if not self.sleepTimerPreview then self:RenderSleepTimer() end;return end
    if resting then self.sleepTimerPreview=nil end
    self.sleepTimerState=self:SleepTimerStep(self.sleepTimerState or {},GetTime(),resting,stacks,expires)
    self:RenderSleepTimer()
end
function P:PreviewSleepTimer()
    if InCombatLockdown() then self:Print(L.combat);return end
    if not self.char then return end
    -- Preview is presentation-only; it never changes the real stack state.
    self.sleepTimerPreview={phase="countdown",stacks=1,deadline=GetTime()+42,hideAt=GetTime()+15,preview=true}
    self:RenderSleepTimer()
end
function P:RegisterSleepTimerOptions()
    if self.sleepTimerOptions or not self.char or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local panel=CreateFrame("Frame");panel.name=L.settings
    local title=panel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge");title:SetPoint("TOPLEFT",16,-16);title:SetText(L.settings)
    local help=panel:CreateFontString(nil,"ARTWORK","GameFontHighlight");help:SetPoint("TOPLEFT",16,-48);help:SetWidth(480);help:SetJustifyH("LEFT");help:SetText(L.help)
    local check=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate");check:SetPoint("TOPLEFT",16,-112)
    local label=panel:CreateFontString(nil,"ARTWORK","GameFontHighlight");label:SetPoint("LEFT",check,"RIGHT",4,0);label:SetText(L.enabled)
    check:SetScript("OnClick",function(s)P.char.sleepTimerEnabled=s:GetChecked()==true;P:UpdateSleepTimer()end)
    panel:SetScript("OnShow",function()check:SetChecked(P.char.sleepTimerEnabled~=false)end)
    local function button(caption,x,click)
        local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");b:SetSize(160,24);b:SetPoint("TOPLEFT",x,-160);b:SetText(caption);b:SetScript("OnClick",click);return b
    end
    button(L.previewButton,16,function()P:PreviewSleepTimer()end)
    button(L.reset,190,function()P.char.sleepTimerPosition=nil;P:PlaceSleepTimer();P:PreviewSleepTimer()end)
    self.sleepTimerOptions=panel;self.sleepTimerCategory=Settings.RegisterCanvasLayoutCategory(panel,L.settings);Settings.RegisterAddOnCategory(self.sleepTimerCategory)
end
local events=CreateFrame("Frame");P.sleepTimerEvents=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","UNIT_AURA","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if not P.char then return end
    if event=="ADDON_LOADED" then P:RegisterSleepTimerOptions();return end
    if event=="UNIT_AURA" and (not plain(unit) or unit~="player") then return end
    if event=="PLAYER_ENTERING_WORLD" then P.sleepTimerState=nil;P.sleepTimerPreview=nil end
    if event=="PLAYER_LOGIN" then P:RegisterSleepTimerOptions() end
    P:UpdateSleepTimer()
end)
SLASH_PROFPADENSLEEP1="/ppsleep"
SlashCmdList.PROFPADENSLEEP=function(msg)
    if not P.char then return end
    if msg=="preview" then P:PreviewSleepTimer()
    elseif msg=="reset" then P.char.sleepTimerPosition=nil;P:PlaceSleepTimer();P:PreviewSleepTimer()
    elseif msg=="on" or msg=="off" then P.char.sleepTimerEnabled=msg=="on";P:UpdateSleepTimer()
    else P:Print(L.commands) end
end
