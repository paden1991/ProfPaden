local _, P = ...
local checks=0
local function check(v,m) checks=checks+1; assert(v,m) end
local state={combat=false,modifier=false,cursor=nil,targeting=false}
local frames={}
function CreateFrame(kind,name,parent,template)
    local f={name=name,visible=true,attrs={},scripts={},events={},lines={},template=template}
    function f:Hide() self.visible=false end
    function f:Show() self.visible=true end
    function f:IsShown() return self.visible end
    f.IsVisible=f.IsShown
    function f:SetAttribute(k,v) check(not state.combat,'no attribute mutation in combat'); self.attrs[k]=v end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:RegisterEvent(e) self.events[e]=true end
    function f:RegisterForClicks(...) self.clicks={...} end
    function f:SetPassThroughButtons(...) self.passthrough={...} end
    function f:SetFrameStrata(s) self.strata=s end
    function f:SetFrameLevel(n) self.level=n end
    function f:GetFrameLevel() return self.level or 1 end
    function f:ClearAllPoints() end
    function f:SetAllPoints(o) self.anchor=o end
    function f:GetOwner() return self.owner end
    function f:SetOwner(o) self.owner=o end
    function f:SetBagItem(b,s) self.bag=b; self.slot=s end
    function f:AddLine(s) self.lines[#self.lines+1]=s end
    function f:AddDoubleLine(l,r) self.lines[#self.lines+1]=l..' | '..r end
    function f:GetPrimaryTooltipData() return self.primary end
    frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
UIParent=CreateFrame('Frame')
GameTooltip=CreateFrame('GameTooltip')
local drivers={}
function RegisterStateDriver(f,key,condition) drivers[key]={frame=f,condition=condition} end
function InCombatLockdown() return state.combat end
function IsModifierKeyDown() return state.modifier end
function IsShiftKeyDown() return state.modifier end
function GetCursorInfo() return state.cursor end
function SpellIsTargeting() return state.targeting end
function GetMoneyString(n) return tostring(n)..' copper' end
Enum={TooltipDataType={Item=0},BagIndex={ReagentBag=5}}
TooltipDataProcessor={AddTooltipPostCall=function(_,callback) P.testTooltip=callback end}
C_Item={GetItemNameByID=function() return nil end}
C_QuestLog=nil
local stock={[0]={[1]={itemID=248682,stackCount=2},[2]={itemID=2449,stackCount=10}}}
C_Container={GetContainerNumSlots=function(b) return b==0 and 6 or 0 end,
    GetContainerItemInfo=function(b,s) return stock[b] and stock[b][s] end}
local prices={[2447]=10,[765]=9,[2449]=15,[785]=30,[2450]=40}
Auctionator={API={v1={GetAuctionPriceByItemID=function(_,id) return prices[id] end,
    GetAuctionAgeByItemID=function() return 0 end, RegisterForDBUpdate=function(_,fn) P.priceUpdated=fn end}}}
Settings={VarType={Boolean='boolean'}}
local registrations,settingsCount=0,0
function Settings.RegisterVerticalLayoutCategory() return {GetID=function() return 31 end} end
function Settings.RegisterAddOnSetting(_,variable,key,db,kind,label,default)
    settingsCount=settingsCount+1
    check(variable=='PadenCrates_'..key and kind=='boolean','stable settings IDs and type')
    return {SetValueChangedCallback=function(self,fn) self.callback=fn end}
end
function Settings.CreateCheckbox() end
function Settings.RegisterAddOnCategory() registrations=registrations+1 end
function Settings.OpenToCategory(id) check(id==31,'open registered native Settings category') end
SlashCmdList={}
PadenCratesDB={enabled=false,autoFill=false}
P.testFrames=frames
P.testRun=function()
    local event=frames[#frames]
    event.scripts.OnEvent(event,'ADDON_LOADED','PadenCrates')
    check(P.db.enabled==false and P.db.autoFill==false,'saved false preferences survive initialization')
    event.scripts.OnEvent(event,'ADDON_LOADED','OtherAddon')
    check(registrations==1 and settingsCount==4,'register category only once with shopping preferences')
    SlashCmdList.PADENCRATES('')
    P.db.enabled=true; P.db.autoFill=true
    local owner=CreateFrame('Button')
    owner.bag,owner.slot=0,1
    function owner:GetBagID() return self.bag end
    function owner:GetID() return self.slot end
    GameTooltip.owner=owner
    GameTooltip.primary={id=248682}
    P.testTooltip(GameTooltip,{id=248682})
    local b=PadenCratesFillButton
    check(b:IsShown() and b.attrs.item2=='0 1','tooltip arms exact carried crate')
    check(b.attrs['target-bag2']==0 and b.attrs['target-slot2']==2,'targets cheapest sufficient material')
    check(b.passthrough[1]=='LeftButton','left-click passes through to original bag button')
    check(b.clicks[1]=='RightButtonUp' and b.attrs.useOnKeyDown==false,'one action on right-button release')
    check(b.template=='SecureActionButtonTemplate,SecureHandlerStateTemplate','native secure action template')
    check(drivers.combat.condition=='[combat] 1; 0','secure combat visibility driver installed')
    check(table.concat(GameTooltip.lines,'\n'):find('150 copper',1,true),'tooltip shows whole cheapest bundle value')
    check(table.concat(GameTooltip.lines,'\n'):find('Right-click: fill one crate',1,true),'ready tooltip reflects armed action')
    -- Simulate the relevant native secure action contract: only target a material if item use creates a targeting cursor.
    local useCount,targetCount=0,0
    local function hardwareRightClick(crateStartsTargeting)
        b.scripts.PreClick(b,'RightButton')
        if b.attrs.type2=='item' then
            useCount=useCount+1
            if crateStartsTargeting then
                check(b.attrs['target-slot2']==2,'secure native targeting receives chosen material slot')
                targetCount=targetCount+1
            end
        end
        b.scripts.PostClick(b,'RightButton')
    end
    hardwareRightClick(true)
    check(useCount==1 and targetCount==1 and not b:IsShown(),'one crate and target per physical click')
    P.Fill.TryArm(GameTooltip,248682)
    hardwareRightClick(false)
    check(useCount==2 and targetCount==1,'failed crate use does not use reagent independently')
    for _,flag in ipairs({'modifier','cursor','targeting'}) do
        state[flag]=true; check(not P.Fill.TryArm(GameTooltip,248682),flag..' preserves manual/native behavior'); state[flag]=nil
    end
    MerchantFrame=CreateFrame('Frame')
    check(not P.Fill.TryArm(GameTooltip,248682),'merchant right-click remains native')
    MerchantFrame:Hide()
    event.scripts.OnEvent(event,'PLAYER_INTERACTION_MANAGER_FRAME_SHOW',8)
    check(not P.Fill.TryArm(GameTooltip,248682),'replacement service UI blocks auto fill')
    event.scripts.OnEvent(event,'PLAYER_INTERACTION_MANAGER_FRAME_HIDE',8)
    check(P.Fill.TryArm(GameTooltip,248682),'service close restores eligibility')
    owner.slot=3
    b.scripts.PreClick(b,'RightButton')
    check(not b.attrs.type2,'recycled bag button cannot operate on prior slot')
    owner.slot=1; P.Fill.TryArm(GameTooltip,248682)
    stock[0][1]={itemID=248683,stackCount=1}
    b.scripts.PreClick(b,'RightButton')
    check(not b.attrs.type2,'replaced crate invalidates armed action')
    stock[0][1]={itemID=248682,stackCount=2}
    P.Fill.TryArm(GameTooltip,248682)
    stock[0][2].isLocked=true
    b.scripts.PreClick(b,'RightButton')
    check(not b.attrs.type2,'revalidate reagent lock immediately before action')
    stock[0][2].isLocked=false
    P.Fill.TryArm(GameTooltip,248682)
    state.combat=true; b:Hide() -- secure state driver fires before insecure handlers.
    check(not P.Fill.TryArm(GameTooltip,248682),'no arming in combat')
    P.Fill.Hide(); b.scripts.PreClick(b,'RightButton')
    state.combat=false
    event.scripts.OnEvent(event,'PLAYER_REGEN_ENABLED')
    check(not b.attrs.type2,'discard old action after combat')
    GameTooltip.lines={}; GameTooltip.primary={id=999}
    P.testTooltip(GameTooltip,{id=248682})
    check(#GameTooltip.lines==0,'nested unrelated item tooltip is untouched')
    GameTooltip.primary={id=248682}; prices[765]=nil
    P.testTooltip(GameTooltip,{id=248682})
    check(table.concat(GameTooltip.lines,'\n'):find('Lowest known fill',1,true),'unknown alternatives not labelled absolute cheapest')
    check(not b:IsShown(),'unknown alternative blocks consumption')
    prices[765]=9
    GameTooltip.lines={}
    local entry,quote=P.Adapter.Quote(264081)
    prices[4392]=12345
    entry,quote=P.Adapter.Quote(264081)
    P.Tooltip.Render(GameTooltip,entry,quote,false,false)
    check(table.concat(GameTooltip.lines,'\n'):find('Writ delivery cost',1,true),'writ tooltip uses required finished item')
    check(table.concat(GameTooltip.lines,'\n'):find('Recorded requirement',1,true),'catalog requirement labelled')
    return checks
end
